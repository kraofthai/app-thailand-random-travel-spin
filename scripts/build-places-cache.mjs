import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const env = loadEnv();
const execFileAsync = promisify(execFile);
const outputPath = new URL('../data/places-cache.json', import.meta.url);
const pageSize = Number(env.TAT_CACHE_PAGE_SIZE || 100);

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
    for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const separator = trimmed.indexOf('=');
      if (separator === -1) continue;
      values[trimmed.slice(0, separator)] = trimmed.slice(separator + 1);
    }
  } catch {}
  return { ...values, ...process.env };
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
  const isCommerce = hasAnyKeyword(text, [
    'shop',
    'store',
    'market',
    'otop',
    'souvenir',
    'ร้านค้า',
    'ตลาด',
    'โอทอป',
    'ของฝาก',
  ]);

  if (isFood) categories.add('food');
  if (isHotel) categories.add('hotelResort');
  if (!isFood && !isHotel && !isCommerce && hasAnyKeyword(text, [
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
  ])) {
    categories.add('nature');
  }
  if (!isFood && !isHotel && !isCommerce && hasAnyKeyword(text, [
    'temple',
    'museum',
    'palace',
    'building',
    'วัด',
    'พิพิธภัณฑ์',
    'พระราชวัง',
    'โบราณสถาน',
    'อาคาร',
  ])) {
    categories.add('building');
  }

  if (categories.size === 0) categories.add('other');
  return [...categories];
}

function normalizeTatPlace(place) {
  const tatId = firstString(place, ['placeId', 'id', 'migrateId', 'slug']);
  if (!tatId) return null;

  const province = firstString(place, [
    'province',
    'province.name',
    'location.province.name',
    'location.province',
  ]) || 'Thailand';
  const category = firstString(place, [
    'category.name',
    'category',
    'sha.category.name',
    'sha.type.name',
    'type.name',
  ]) || 'อื่นๆ';
  const description = firstString(place, [
    'description',
    'introduction',
    'detail',
    'sha.detail',
  ]) || '';
  const name = firstString(place, ['name', 'sha.name', 'title', 'place_name']) || 'ไม่ทราบชื่อ';
  const filterText = [name, province, category, description, JSON.stringify(place)].join(' ');

  return {
    tatId,
    name,
    province,
    region: provinceToRegion[province] || 'จาก API',
    category,
    categoryFilters: categoryFiltersForText(filterText),
    description,
    latitude: firstNumber(place, ['latitude', 'lat', 'location.latitude']),
    longitude: firstNumber(place, ['longitude', 'lng', 'lon', 'location.longitude']),
    imageUrl: firstImageUrl(place),
    source: 'TAT',
    lastSyncedAt: new Date().toISOString(),
    isActive: true,
    randomKey: Math.random(),
  };
}

function buildTatPlacesUrl({ page = 1, limit = pageSize } = {}) {
  const baseUrl = (env.TAT_API_BASE_URL || 'https://tatdataapi.io').replace(/\/$/, '');
  const placesPath = env.TAT_API_PLACES_PATH || '/api/v2/places';
  const target = new URL(`${baseUrl}${placesPath}`);
  target.searchParams.set('limit', String(limit));
  target.searchParams.set('locale', env.TAT_API_LOCALE || 'en');
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

if (!env.TAT_API_KEY) {
  throw new Error('Missing TAT_API_KEY');
}

const firstUrl = buildTatPlacesUrl({ page: 1 });
console.log(`Fetching TAT places ${firstUrl.href}`);
const firstPage = await fetchTatJson(firstUrl);
const total = Number(firstPage?.pagination?.total || firstPage?.data?.length || 0);
const totalPages = Math.max(1, Math.ceil(total / pageSize));
const rawPlaces = Array.isArray(firstPage.data) ? [...firstPage.data] : [];
let nextPage = 2;
const concurrency = 5;

async function worker() {
  while (nextPage <= totalPages) {
    const page = nextPage++;
    const payload = await fetchTatJson(buildTatPlacesUrl({ page }));
    if (Array.isArray(payload.data)) rawPlaces.push(...payload.data);
    if (page % 20 === 0 || page === totalPages) {
      console.log(`Fetched page ${page}/${totalPages}`);
    }
  }
}

await Promise.all(Array.from({ length: Math.min(concurrency, totalPages) }, () => worker()));

const data = rawPlaces.map(normalizeTatPlace).filter(Boolean);
const payload = {
  data,
  pagination: {
    pageNumber: 1,
    pageSize,
    total: data.length,
    totalFromTat: total,
    totalPages,
  },
  source: 'tat-cache-file',
  cachedAt: new Date().toISOString(),
};

mkdirSync(new URL('../data', import.meta.url), { recursive: true });
writeFileSync(outputPath, JSON.stringify(payload));
console.log(`Wrote ${data.length} places to ${outputPath.pathname}`);
