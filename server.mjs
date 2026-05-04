import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const env = loadEnv();
const port = Number(env.PORT || 3000);
const host = env.HOST || '0.0.0.0';
const execFileAsync = promisify(execFile);
let allPlacesCache = null;
let allPlacesCachePromise = null;

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
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(JSON.stringify(payload));
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
  if (!env.TAT_API_KEY) {
    sendJson(response, 500, { error: 'Missing TAT_API_KEY' });
    return;
  }

  const incoming = new URL(request.url, `http://127.0.0.1:${port}`);
  const refresh = incoming.searchParams.get('refresh') === '1';
  const pageSize = Number(incoming.searchParams.get('pageSize') || 100);

  if (refresh) {
    allPlacesCache = null;
    allPlacesCachePromise = null;
  }

  try {
    const payload = await fetchAllTatPlaces({ pageSize });
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 502, {
      error: 'Unable to fetch all places from TAT API',
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
