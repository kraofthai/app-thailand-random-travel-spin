const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const tatApiKey = defineSecret("TAT_API_KEY");
const TAT_API_BASE_URL = "https://tatdataapi.io";
const TAT_API_PLACES_PATH = "/api/v2/places";
const TAT_API_AUTH_HEADER = "x-api-key";
const TAT_API_DEFAULT_LOCALE = "en";
let allPlacesCache = null;
let allPlacesCachePromise = null;

const POINT_RULES = Object.freeze({
  daily_open: 5,
  spin_trip: 2,
  save_place: 3,
  check_in: 20,
  review_upload: 10,
  check_in_review: 30,
  challenge_complete: 25,
  invite_friend: 30,
});

exports.awardPointTransaction = onCall(
  {region: "asia-east2"},
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const type = String(request.data && request.data.type || "");
    const description = String(request.data && request.data.description || "");
    const points = POINT_RULES[type];

    if (!points) {
      throw new HttpsError("invalid-argument", "Unsupported point type.");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const transactionRef = db.collection("point_transactions").doc();
    const leaderboardRef = db.collection("leaderboard").doc(uid);
    const month = new Date().toISOString().slice(0, 7);

    await db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(userRef);
      const userData = userSnapshot.exists ? userSnapshot.data() : {};
      const currentPoints = userSnapshot.exists
        ? Number(userData.points || 0)
        : 0;
      const nextPoints = currentPoints + points;

      transaction.set(
        userRef,
        {
          uid,
          points: admin.firestore.FieldValue.increment(points),
          level: Math.max(1, Math.floor(nextPoints / 250) + 1),
          lastLogin: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      transaction.set(transactionRef, {
        userId: uid,
        type,
        points,
        description,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(
        leaderboardRef,
        {
          userId: uid,
          displayName: userData.displayName || "นักเดินทาง",
          photoUrl: userData.photoUrl || null,
          points: admin.firestore.FieldValue.increment(points),
          month,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    return {ok: true, points};
  },
);

function sendJson(response, statusCode, payload) {
  response.status(statusCode).set({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  }).json(payload);
}

function buildTatPlacesUrl({
  page = 1,
  limit = 100,
  locale = TAT_API_DEFAULT_LOCALE,
  requestUrl,
} = {}) {
  const target = new URL(`${TAT_API_BASE_URL}${TAT_API_PLACES_PATH}`);
  const source = requestUrl ? new URL(requestUrl, "https://teawnaid.local") : null;
  const params = source ? source.searchParams : new URLSearchParams();
  target.searchParams.set("limit", String(params.get("limit") || limit));
  target.searchParams.set("locale", params.get("locale") || locale);
  target.searchParams.set("page", String(params.get("page") || page));
  target.searchParams.set("hasName", params.get("hasName") || "1");
  target.searchParams.set(
    "hasIntroduction",
    params.get("hasIntroduction") || "1",
  );
  target.searchParams.set("hasThumbnail", params.get("hasThumbnail") || "1");

  for (const key of ["province", "region", "keyword", "category"]) {
    const value = params.get(key);
    if (value) target.searchParams.set(key, value);
  }

  return target;
}

async function fetchTatJson(target) {
  const response = await fetch(target, {
    headers: {
      "Accept": "application/json",
      [TAT_API_AUTH_HEADER]: tatApiKey.value(),
    },
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`TAT API returned ${response.status}: ${detail}`);
  }

  return response.json();
}

async function fetchAllTatPlaces({pageSize = 100, refresh = false} = {}) {
  if (refresh) {
    allPlacesCache = null;
    allPlacesCachePromise = null;
  }

  if (allPlacesCache) return allPlacesCache;
  if (allPlacesCachePromise) return allPlacesCachePromise;

  allPlacesCachePromise = (async () => {
    const firstPage = await fetchTatJson(
      buildTatPlacesUrl({page: 1, limit: pageSize}),
    );
    const total = Number(
      (firstPage.pagination && firstPage.pagination.total) ||
        (Array.isArray(firstPage.data) ? firstPage.data.length : 0),
    );
    const totalPages = Math.max(1, Math.ceil(total / pageSize));
    const places = Array.isArray(firstPage.data) ? [...firstPage.data] : [];
    const concurrency = 5;
    let nextPage = 2;

    async function worker() {
      while (nextPage <= totalPages) {
        const page = nextPage++;
        const payload = await fetchTatJson(
          buildTatPlacesUrl({page, limit: pageSize}),
        );
        if (Array.isArray(payload.data)) places.push(...payload.data);
      }
    }

    await Promise.all(
      Array.from({length: Math.min(concurrency, totalPages)}, () => worker()),
    );

    allPlacesCache = {
      data: places,
      pagination: {
        pageNumber: 1,
        pageSize,
        total: places.length,
        totalFromTat: total,
        totalPages,
      },
      cachedAt: new Date().toISOString(),
    };
    allPlacesCachePromise = null;
    return allPlacesCache;
  })();

  try {
    return await allPlacesCachePromise;
  } catch (error) {
    allPlacesCachePromise = null;
    throw error;
  }
}

async function handlePlaces(request, response) {
  try {
    const payload = await fetchTatJson(
      buildTatPlacesUrl({requestUrl: request.originalUrl || request.url}),
    );
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 502, {
      error: "Unable to fetch places from TAT API",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleAllPlaces(request, response) {
  try {
    const refresh = request.query.refresh === "1";
    const pageSize = Number(request.query.pageSize || 100);
    const payload = await fetchAllTatPlaces({pageSize, refresh});
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 502, {
      error: "Unable to fetch all places from TAT API",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleImage(request, response) {
  const rawUrl = String(request.query.url || "");
  if (!rawUrl) {
    sendJson(response, 400, {error: "Missing image url"});
    return;
  }

  let target;
  try {
    target = new URL(rawUrl);
  } catch {
    sendJson(response, 400, {error: "Invalid image url"});
    return;
  }

  const allowedHost =
    target.hostname === "dmc.tatdataapi.io" ||
    target.hostname.endsWith(".tatdataapi.io");

  if (target.protocol !== "https:" || !allowedHost) {
    sendJson(response, 400, {error: "Unsupported image host"});
    return;
  }

  try {
    const imageResponse = await fetch(target, {
      headers: {"User-Agent": "TeawNaiD/1.0"},
    });

    if (!imageResponse.ok) {
      sendJson(response, imageResponse.status, {
        error: "Unable to fetch image",
      });
      return;
    }

    const bytes = Buffer.from(await imageResponse.arrayBuffer());
    response.status(200).set({
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "public, max-age=86400",
      "Content-Type": imageResponse.headers.get("content-type") || "image/jpeg",
    }).send(bytes);
  } catch (error) {
    sendJson(response, 502, {
      error: "Unable to proxy image",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

exports.travelApi = onRequest(
  {
    region: "asia-east2",
    cors: true,
    secrets: [tatApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request, response) => {
    if (request.method === "OPTIONS") {
      sendJson(response, 204, {});
      return;
    }

    const pathname = request.path || "/";
    if (request.method === "GET" && pathname === "/health") {
      sendJson(response, 200, {ok: true, provider: "tat"});
      return;
    }

    if (request.method === "GET" && pathname === "/api/places") {
      await handlePlaces(request, response);
      return;
    }

    if (request.method === "GET" && pathname === "/api/places/all") {
      await handleAllPlaces(request, response);
      return;
    }

    if (request.method === "GET" && pathname === "/api/image") {
      await handleImage(request, response);
      return;
    }

    sendJson(response, 404, {error: "Not found"});
  },
);
