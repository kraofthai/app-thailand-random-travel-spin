import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import admin from 'firebase-admin';

const env = loadEnv();
const port = Number(env.PORT || 3000);
const host = env.HOST || '0.0.0.0';
const knownPlacesTotal = Number(env.PLACES_TOTAL_COUNT || 20110);
const execFileAsync = promisify(execFile);
let allPlacesCache = null;
let allPlacesCachePromise = null;
let firestore = null;

const provinceToRegion = {
  เชียงใหม่: 'ภาคเหนือ',
  เชียงราย: 'ภาคเหนือ',
  แม่ฮ่องสอน: 'ภาคเหนือ',
  ลำพูน: 'ภาคเหนือ',
  ลำปาง: 'ภาคเหนือ',
  แพร่: 'ภาคเหนือ',
  น่าน: 'ภาคเหนือ',
  พะเยา: 'ภาคเหนือ',
  อุตรดิตถ์: 'ภาคเหนือ',
  ตาก: 'ภาคเหนือ',
  สุโขทัย: 'ภาคเหนือ',
  พิษณุโลก: 'ภาคเหนือ',
  พิจิตร: 'ภาคเหนือ',
  กำแพงเพชร: 'ภาคเหนือ',
  เพชรบูรณ์: 'ภาคเหนือ',
  กรุงเทพมหานคร: 'ภาคกลาง',
  พระนครศรีอยุธยา: 'ภาคกลาง',
  นนทบุรี: 'ภาคกลาง',
  ปทุมธานี: 'ภาคกลาง',
  สมุทรปราการ: 'ภาคกลาง',
  นครปฐม: 'ภาคกลาง',
  สมุทรสาคร: 'ภาคกลาง',
  สมุทรสงคราม: 'ภาคกลาง',
  สระบุรี: 'ภาคกลาง',
  ลพบุรี: 'ภาคกลาง',
  สิงห์บุรี: 'ภาคกลาง',
  ชัยนาท: 'ภาคกลาง',
  อ่างทอง: 'ภาคกลาง',
  นครสวรรค์: 'ภาคกลาง',
  อุทัยธานี: 'ภาคกลาง',
  สุพรรณบุรี: 'ภาคกลาง',
  อุบลราชธานี: 'ภาคอีสาน',
  เลย: 'ภาคอีสาน',
  บุรีรัมย์: 'ภาคอีสาน',
  ขอนแก่น: 'ภาคอีสาน',
  อุดรธานี: 'ภาคอีสาน',
  หนองคาย: 'ภาคอีสาน',
  บึงกาฬ: 'ภาคอีสาน',
  หนองบัวลำภู: 'ภาคอีสาน',
  สกลนคร: 'ภาคอีสาน',
  นครพนม: 'ภาคอีสาน',
  มุกดาหาร: 'ภาคอีสาน',
  กาฬสินธุ์: 'ภาคอีสาน',
  ร้อยเอ็ด: 'ภาคอีสาน',
  มหาสารคาม: 'ภาคอีสาน',
  ยโสธร: 'ภาคอีสาน',
  อำนาจเจริญ: 'ภาคอีสาน',
  ศรีสะเกษ: 'ภาคอีสาน',
  สุรินทร์: 'ภาคอีสาน',
  ชัยภูมิ: 'ภาคอีสาน',
  นครราชสีมา: 'ภาคตะวันออก',
  ระยอง: 'ภาคตะวันออก',
  ชลบุรี: 'ภาคตะวันออก',
  ฉะเชิงเทรา: 'ภาคตะวันออก',
  ปราจีนบุรี: 'ภาคตะวันออก',
  สระแก้ว: 'ภาคตะวันออก',
  จันทบุรี: 'ภาคตะวันออก',
  ตราด: 'ภาคตะวันออก',
  สุราษฎร์ธานี: 'ภาคใต้',
  ภูเก็ต: 'ภาคใต้',
  สตูล: 'ภาคใต้',
  ชุมพร: 'ภาคใต้',
  ระนอง: 'ภาคใต้',
  พังงา: 'ภาคใต้',
  กระบี่: 'ภาคใต้',
  นครศรีธรรมราช: 'ภาคใต้',
  ตรัง: 'ภาคใต้',
  พัทลุง: 'ภาคใต้',
  สงขลา: 'ภาคใต้',
  ปัตตานี: 'ภาคใต้',
  ยะลา: 'ภาคใต้',
  นราธิวาส: 'ภาคใต้',
  กาญจนบุรี: 'ภาคตะวันตก',
  ประจวบคีรีขันธ์: 'ภาคตะวันตก',
  ราชบุรี: 'ภาคตะวันตก',
  เพชรบุรี: 'ภาคตะวันตก',
};

function loadEnv() {
  const values = {};

  try {
    const lines = readFileSync(new URL('./.env', import.meta.url), 'utf8')
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('#'));

    for (const line of lines) {
      const separator = line.indexOf('=');
      if (separator === -1) continue;
      values[line.slice(0, separator)] = line.slice(separator + 1);
    }
  } catch {
    // Environment variables can still be provided by the shell in production.
  }

  return { ...values, ...process.env };
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, x-admin-token',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(JSON.stringify(payload));
}

function getRequestBody(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error('Request body too large'));
        request.destroy();
      }
    });
    request.on('end', () => resolve(body));
    request.on('error', reject);
  });
}

function getFirestore() {
  if (firestore) return firestore;

  const projectId = env.FIREBASE_PROJECT_ID;
  const clientEmail = env.FIREBASE_CLIENT_EMAIL;
  const privateKey = env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      'Missing Firestore credentials. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY.',
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }

  firestore = admin.firestore();
  return firestore;
}

function valueAt(source, path) {
  return path.split('.').reduce((current, key) => {
    if (current == null) return undefined;
    if (Array.isArray(current)) return current[Number(key)];
    return current[key];
  }, source);
}

function firstString(source, paths) {
  for (const path of paths) {
    const value = valueAt(source, path);
    if (typeof value === 'string' && value.trim()) return value.trim();
    if (typeof value === 'number') return String(value);
  }
  return null;
}

function firstNumber(source, paths) {
  for (const path of paths) {
    const value = valueAt(source, path);
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string') {
      const parsed = Number(value.trim());
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function firstImageUrl(source) {
  const paths = [
    'sha.thumbnailUrl',
    'sha.detailThumbnail',
    'sha.detailPicture.0',
    'thumbnailUrl.0',
    'thumbnailUrl',
    'imageUrl',
    'photoUrl',
  ];

  for (const path of paths) {
    const value = valueAt(source, path);
    if (typeof value === 'string' && value.trim()) return value.trim();
    if (Array.isArray(value)) {
      const match = value.find((item) => typeof item === 'string' && item.trim());
      if (match) return match.trim();
    }
  }

  return null;
}

function hasAnyKeyword(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword));
}

function categoryFiltersForText(rawText) {
  const text = rawText.toLowerCase();
  const categories = new Set();
  const isFood = hasAnyKeyword(text, [
    'restaurant',
    'cafe',
    'coffee',
    'bakery',
    'food',
    'ร้านอาหาร',
    'กาแฟ',
    'คาเฟ่',
    'เบเกอรี่',
  ]);
  const isHotel = hasAnyKeyword(text, [
    'hotel',
    'resort',
    'hostel',
    'villa',
    'โรงแรม',
    'รีสอร์ต',
    'ที่พัก',
  ]);

  if (isFood) categories.add('food');
  if (isHotel) categories.add('hotelResort');
  if (
    !isFood &&
    !isHotel &&
    hasAnyKeyword(text, [
      'nature',
      'park',
      'forest',
      'waterfall',
      'mountain',
      'beach',
      'island',
      'sea',
      'river',
      'lake',
      'ธรรมชาติ',
      'อุทยาน',
      'ป่า',
      'น้ำตก',
      'ภูเขา',
      'หาด',
      'เกาะ',
      'ทะเล',
      'แม่น้ำ',
    ])
  ) {
    categories.add('nature');
  }
  if (
    !isFood &&
    !isHotel &&
    hasAnyKeyword(text, [
      'temple',
      'museum',
      'palace',
      'building',
      'วัด',
      'พิพิธภัณฑ์',
      'พระราชวัง',
      'โบราณสถาน',
      'อาคาร',
    ])
  ) {
    categories.add('building');
  }

  if (categories.size === 0) categories.add('other');
  return [...categories];
}

function normalizeTatPlace(place) {
  const tatId = firstString(place, [
    'placeId',
    'id',
    'migrateId',
    'slug',
  ]);

  if (!tatId) return null;

  const province =
    firstString(place, [
      'province',
      'province.name',
      'location.province.name',
      'location.province',
    ]) || 'Thailand';
  const category =
    firstString(place, [
      'category.name',
      'category',
      'sha.category.name',
      'sha.type.name',
      'type.name',
    ]) || 'อื่นๆ';
  const description =
    firstString(place, [
      'description',
      'introduction',
      'detail',
      'sha.detail',
    ]) || '';
  const filterText = [
    firstString(place, ['name', 'sha.name', 'title', 'place_name']) || '',
    province,
    category,
    description,
    JSON.stringify(place),
  ].join(' ');

  return {
    tatId,
    name:
      firstString(place, ['name', 'sha.name', 'title', 'place_name']) ||
      'ไม่ทราบชื่อ',
    province,
    region: provinceToRegion[province] || 'จาก API',
    category,
    categoryFilters: categoryFiltersForText(filterText),
    description,
    latitude: firstNumber(place, ['latitude', 'lat', 'location.latitude']),
    longitude: firstNumber(place, ['longitude', 'lng', 'lon', 'location.longitude']),
    imageUrl: firstImageUrl(place),
    source: 'TAT',
    lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true,
    randomKey: Math.random(),
    raw: place,
  };
}

function buildTatUrl(requestUrl) {
  const incoming = new URL(requestUrl, `http://127.0.0.1:${port}`);
  const baseUrl = (env.TAT_API_BASE_URL || 'https://tatdataapi.io').replace(
    /\/$/,
    '',
  );
  const placesPath = env.TAT_API_PLACES_PATH || '/api/v2/places';
  const target = new URL(`${baseUrl}${placesPath}`);
  const limit = incoming.searchParams.get('limit') || env.TAT_API_DEFAULT_LIMIT || '20';
  const locale = incoming.searchParams.get('locale') || env.TAT_API_LOCALE || 'en';

  target.searchParams.set('limit', limit);
  target.searchParams.set('locale', locale);
  target.searchParams.set('page', incoming.searchParams.get('page') || '1');
  target.searchParams.set(
    'hasName',
    incoming.searchParams.get('hasName') || '1',
  );
  target.searchParams.set(
    'hasIntroduction',
    incoming.searchParams.get('hasIntroduction') || '1',
  );
  target.searchParams.set(
    'hasThumbnail',
    incoming.searchParams.get('hasThumbnail') || '1',
  );

  for (const key of ['province', 'region', 'keyword', 'category']) {
    const value = incoming.searchParams.get(key);
    if (value) target.searchParams.set(key, value);
  }

  return target;
}

function buildTatPlacesUrl({ page = 1, limit = 100, locale = env.TAT_API_LOCALE || 'en' } = {}) {
  const baseUrl = (env.TAT_API_BASE_URL || 'https://tatdataapi.io').replace(
    /\/$/,
    '',
  );
  const placesPath = env.TAT_API_PLACES_PATH || '/api/v2/places';
  const target = new URL(`${baseUrl}${placesPath}`);
  target.searchParams.set('limit', String(limit));
  target.searchParams.set('locale', locale);
  target.searchParams.set('page', String(page));
  target.searchParams.set('hasName', '1');
  target.searchParams.set('hasIntroduction', '1');
  target.searchParams.set('hasThumbnail', '1');
  return target;
}

async function fetchTatJson(target) {
  const authHeader = env.TAT_API_AUTH_HEADER || 'x-api-key';
  const keyPrefix = env.TAT_API_KEY_PREFIX || '';
  const { stdout } = await execFileAsync(
    'curl',
    [
      '--silent',
      '--show-error',
      '--location',
      target.href,
      '-H',
      'Accept: application/json',
      '-H',
      `${authHeader}: ${keyPrefix}${env.TAT_API_KEY}`,
    ],
    { timeout: 30000, maxBuffer: 1024 * 1024 * 20 },
  );
  return JSON.parse(stdout);
}

async function fetchAllTatPlaces({ pageSize = 100 } = {}) {
  if (allPlacesCache) return allPlacesCache;
  if (allPlacesCachePromise) return allPlacesCachePromise;

  allPlacesCachePromise = (async () => {
    const firstUrl = buildTatPlacesUrl({ page: 1, limit: pageSize });
    console.log(`Fetching all TAT places from ${firstUrl.href}`);
    const firstPage = await fetchTatJson(firstUrl);
    const total = Number(firstPage?.pagination?.total || firstPage?.data?.length || 0);
    const totalPages = Math.max(1, Math.ceil(total / pageSize));
    const places = Array.isArray(firstPage.data) ? [...firstPage.data] : [];
    const concurrency = 5;
    let nextPage = 2;

    async function worker() {
      while (nextPage <= totalPages) {
        const page = nextPage++;
        const pageUrl = buildTatPlacesUrl({ page, limit: pageSize });
        const payload = await fetchTatJson(pageUrl);
        if (Array.isArray(payload.data)) {
          places.push(...payload.data);
        }
        if (page % 20 === 0 || page === totalPages) {
          console.log(`Fetched TAT places page ${page}/${totalPages}`);
        }
      }
    }

    await Promise.all(
      Array.from({ length: Math.min(concurrency, totalPages) }, () => worker()),
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
  if (!env.TAT_API_KEY) {
    sendJson(response, 500, { error: 'Missing TAT_API_KEY' });
    return;
  }

  const target = buildTatUrl(request.url);
  const authHeader = env.TAT_API_AUTH_HEADER || 'x-api-key';
  const keyPrefix = env.TAT_API_KEY_PREFIX || '';

  try {
    console.log(`Proxying TAT places: ${target.href}`);
    const { stdout } = await execFileAsync(
      'curl',
      [
        '--silent',
        '--show-error',
        '--location',
        target.href,
        '-H',
        'Accept: application/json',
        '-H',
        `${authHeader}: ${keyPrefix}${env.TAT_API_KEY}`,
      ],
      { timeout: 15000, maxBuffer: 1024 * 1024 * 5 },
    );

    response.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Content-Type': 'application/json; charset=utf-8',
    });
    response.end(stdout);
  } catch (error) {
    sendJson(response, 502, {
      error: 'Unable to fetch places from TAT API',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleAllPlaces(request, response) {
  const incoming = new URL(request.url, `http://127.0.0.1:${port}`);
  const refresh = incoming.searchParams.get('refresh') === '1';
  const pageSize = Number(incoming.searchParams.get('pageSize') || 100);

  try {
    if (!refresh) {
      const cachedPayload = await fetchCachedPlaces({
        limit: Number(incoming.searchParams.get('limit') || 50000),
        province: incoming.searchParams.get('province'),
        region: incoming.searchParams.get('region'),
        category: incoming.searchParams.get('category'),
        categoryFilter: incoming.searchParams.get('categoryFilter'),
      });
      if (cachedPayload.data.length > 0) {
        sendJson(response, 200, cachedPayload);
        return;
      }
    }

    if (!env.TAT_API_KEY) {
      sendJson(response, 500, { error: 'Missing TAT_API_KEY' });
      return;
    }

    if (refresh) {
      allPlacesCache = null;
      allPlacesCachePromise = null;
    }

    const payload = await fetchAllTatPlaces({ pageSize });
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 502, {
      error: 'Unable to fetch all places from TAT API',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function fetchCachedPlaces({
  limit = 100,
  province,
  region,
  category,
  categoryFilter,
} = {}) {
  const db = getFirestore();
  const safeLimit = Math.max(1, Math.min(Number(limit) || 100, 50000));
  let query = db.collection('places').where('isActive', '==', true);

  if (province) query = query.where('province', '==', province);
  if (region) query = query.where('region', '==', region);
  if (categoryFilter) {
    query = query.where('categoryFilters', 'array-contains', categoryFilter);
  }
  if (category) query = query.where('category', '==', category);

  const snapshot = await query.limit(safeLimit).get();
  const data = snapshot.docs.map((doc) => publicPlace(doc.data()));
  const hasFilter = Boolean(province || region || category || categoryFilter);

  return {
    data,
    pagination: {
      pageNumber: 1,
      pageSize: safeLimit,
      total: hasFilter ? data.length : Math.max(knownPlacesTotal, data.length),
      returned: data.length,
    },
    source: 'firestore',
    cachedAt: new Date().toISOString(),
  };
}

function publicPlace(place) {
  if (!place) return place;
  return {
    tatId: place.tatId,
    name: place.name,
    province: place.province,
    region: place.region,
    category: place.category,
    categoryFilters: place.categoryFilters || [],
    description: place.description || '',
    latitude: place.latitude ?? null,
    longitude: place.longitude ?? null,
    imageUrl: place.imageUrl || null,
    source: place.source || 'TAT',
    isActive: place.isActive !== false,
    lastSyncedAt: place.lastSyncedAt || null,
  };
}

async function handleCachedPlaces(request, response) {
  try {
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const payload = await fetchCachedPlaces({
      limit: url.searchParams.get('limit') || env.TAT_API_DEFAULT_LIMIT || 20,
      province: url.searchParams.get('province'),
      region: url.searchParams.get('region'),
      category: url.searchParams.get('category'),
      categoryFilter: url.searchParams.get('categoryFilter'),
    });
    sendJson(response, 200, payload);
  } catch (error) {
    console.error('Unable to read cached places', error);
    sendJson(response, 500, {
      error: 'Unable to read cached places',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleRandomCachedPlace(request, response) {
  try {
    const db = getFirestore();
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const province = url.searchParams.get('province');
    const region = url.searchParams.get('region');
    const category = url.searchParams.get('category');
    const categoryFilter = url.searchParams.get('categoryFilter');
    const seed = Math.random();
    let snapshot;

    function filteredQuery() {
      let query = db.collection('places').where('isActive', '==', true);
      if (province) query = query.where('province', '==', province);
      if (region) query = query.where('region', '==', region);
      if (categoryFilter) {
        query = query.where('categoryFilters', 'array-contains', categoryFilter);
      }
      if (category) query = query.where('category', '==', category);
      return query;
    }

    try {
      snapshot = await filteredQuery()
        .where('randomKey', '>=', seed)
        .orderBy('randomKey')
        .limit(1)
        .get();

      if (snapshot.empty) {
        snapshot = await filteredQuery()
          .orderBy('randomKey')
          .limit(1)
          .get();
      }
    } catch (indexError) {
      console.warn('Random indexed query failed; falling back to sampled query', indexError);
      snapshot = await filteredQuery().limit(1000).get();
    }

    if (snapshot.empty) {
      sendJson(response, 404, { error: 'No active places found' });
      return;
    }

    const docs = snapshot.docs;
    const doc = docs.length === 1 ? docs[0] : docs[Math.floor(Math.random() * docs.length)];
    sendJson(response, 200, { data: publicPlace(doc.data()), source: 'firestore' });
  } catch (error) {
    console.error('Unable to read random cached place', error);
    sendJson(response, 500, {
      error: 'Unable to read random cached place',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleCachedPlaceDetail(request, response, tatId) {
  try {
    const doc = await getFirestore().collection('places').doc(tatId).get();
    if (!doc.exists) {
      sendJson(response, 404, { error: 'Place not found' });
      return;
    }
    sendJson(response, 200, { data: publicPlace(doc.data()), source: 'firestore' });
  } catch (error) {
    console.error(`Unable to read cached place ${tatId}`, error);
    sendJson(response, 500, {
      error: 'Unable to read cached place',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleSyncPlaces(request, response) {
  if (request.headers['x-admin-token'] !== env.ADMIN_SYNC_TOKEN) {
    sendJson(response, 401, { error: 'Unauthorized' });
    return;
  }

  if (!env.ADMIN_SYNC_TOKEN) {
    sendJson(response, 500, { error: 'Missing ADMIN_SYNC_TOKEN' });
    return;
  }

  if (!env.TAT_API_KEY) {
    sendJson(response, 500, { error: 'Missing TAT_API_KEY' });
    return;
  }

  try {
    await getRequestBody(request);
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const pageSize = Number(url.searchParams.get('pageSize') || 100);
    console.log(`Starting TAT places sync with pageSize=${pageSize}`);

    const payload = await fetchAllTatPlaces({ pageSize });
    const places = Array.isArray(payload.data) ? payload.data : [];
    const db = getFirestore();
    let batch = db.batch();
    let writesInBatch = 0;
    let synced = 0;
    let skipped = 0;

    async function commitIfNeeded(force = false) {
      if (!force && writesInBatch < 450) return;
      if (writesInBatch === 0) return;
      await batch.commit();
      batch = db.batch();
      writesInBatch = 0;
    }

    for (const place of places) {
      const normalized = normalizeTatPlace(place);
      if (!normalized) {
        skipped++;
        continue;
      }

      batch.set(db.collection('places').doc(normalized.tatId), normalized, {
        merge: true,
      });
      writesInBatch++;
      synced++;
      await commitIfNeeded();
    }

    await commitIfNeeded(true);
    console.log(`TAT places sync completed: synced=${synced}, skipped=${skipped}`);

    sendJson(response, 200, {
      ok: true,
      synced,
      skipped,
      totalFromTat: payload.pagination?.totalFromTat || places.length,
      collection: 'places',
    });
  } catch (error) {
    console.error('Unable to sync TAT places', error);
    sendJson(response, 500, {
      error: 'Unable to sync TAT places',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

async function handleImage(request, response) {
  const incoming = new URL(request.url, `http://127.0.0.1:${port}`);
  const rawUrl = incoming.searchParams.get('url');

  if (!rawUrl) {
    sendJson(response, 400, { error: 'Missing image url' });
    return;
  }

  let target;
  try {
    target = new URL(rawUrl);
  } catch {
    sendJson(response, 400, { error: 'Invalid image url' });
    return;
  }

  const allowedHost =
    target.hostname === 'dmc.tatdataapi.io' ||
    target.hostname.endsWith('.tatdataapi.io');

  if (target.protocol !== 'https:' || !allowedHost) {
    sendJson(response, 400, { error: 'Unsupported image host' });
    return;
  }

  try {
    const imageResponse = await fetch(target, {
      headers: { 'User-Agent': 'ThailandRandomTravel/1.0' },
    });

    if (!imageResponse.ok) {
      sendJson(response, imageResponse.status, {
        error: 'Unable to fetch image',
      });
      return;
    }

    const bytes = Buffer.from(await imageResponse.arrayBuffer());
    response.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=86400',
      'Content-Type':
        imageResponse.headers.get('content-type') || 'image/jpeg',
    });
    response.end(bytes);
  } catch (error) {
    sendJson(response, 502, {
      error: 'Unable to proxy image',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

const server = createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    sendJson(response, 204, {});
    return;
  }

  const url = new URL(request.url, `http://127.0.0.1:${port}`);

  if (request.method === 'GET' && url.pathname === '/health') {
    sendJson(response, 200, { ok: true, provider: env.PLACES_PROVIDER || 'tat' });
    return;
  }

  if (request.method === 'POST' && url.pathname === '/admin/sync-places') {
    await handleSyncPlaces(request, response);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/places') {
    await handleCachedPlaces(request, response);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/places/random') {
    await handleRandomCachedPlace(request, response);
    return;
  }

  if (request.method === 'GET' && url.pathname.startsWith('/places/')) {
    const tatId = decodeURIComponent(url.pathname.replace('/places/', ''));
    await handleCachedPlaceDetail(request, response, tatId);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/api/places') {
    await handlePlaces(request, response);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/api/places/all') {
    await handleAllPlaces(request, response);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/api/image') {
    await handleImage(request, response);
    return;
  }

  sendJson(response, 404, { error: 'Not found' });
});

server.listen(port, host, () => {
  console.log(`Travel API proxy listening on http://${host}:${port}`);
});
