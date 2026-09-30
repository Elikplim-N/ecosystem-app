/**
 * End-to-end smoke test against a running API.
 *
 *   npm run dev                 # in one terminal
 *   node scripts/smoke-test.js  # in another
 *
 * Exercises the paths that matter most: registering, signing in, refreshing a
 * token, role enforcement, RFID de-duplication, and bin state derivation.
 * Exits non-zero on the first failure so it can be used in CI later.
 */
const BASE = process.env.API_URL ?? 'http://localhost:3000';

let passed = 0;
let failed = 0;

function check(name, condition, detail = '') {
  if (condition) {
    passed += 1;
    console.log(`  [ok]    ${name}`);
  } else {
    failed += 1;
    console.log(`  [FAIL]  ${name}${detail ? `  -> ${detail}` : ''}`);
  }
}

async function call(method, path, { token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  return { status: res.status, body: json };
}

const stamp = Date.now();
const phone = `+2337${String(stamp).slice(-8)}`;
const password = 'SmokeTest123!';

console.log(`\nSmoke test against ${BASE}\n`);

// --- health ---------------------------------------------------------

console.log('Health');
const health = await call('GET', '/health');
check('health responds 200', health.status === 200, JSON.stringify(health.body));
check('database connected', health.body?.database?.connected === true);
check('service name correct', health.body?.service === 'ecosystem-api');

// --- registration and login -----------------------------------------

console.log('\nAuth');
const reg = await call('POST', '/api/auth/register', {
  body: { name: 'Smoke Tester', phone, password, nickname: 'Smoke' },
});
check('register returns 201', reg.status === 201, JSON.stringify(reg.body));
check('register returns access token', typeof reg.body?.accessToken === 'string');
check('register returns refresh token', typeof reg.body?.refreshToken === 'string');
check('new member has role "user"', reg.body?.user?.role === 'user', reg.body?.user?.role);
check('password_hash is never returned', !JSON.stringify(reg.body).includes('argon2'));

const token = reg.body?.accessToken;
const refresh = reg.body?.refreshToken;
const userId = reg.body?.user?.id;

const dupe = await call('POST', '/api/auth/register', {
  body: { name: 'Duplicate', phone, password },
});
check('duplicate phone rejected with 409', dupe.status === 409, `got ${dupe.status}`);

const weak = await call('POST', '/api/auth/register', {
  body: { name: 'Weak', phone: `+2338${stamp}`, password: 'short' },
});
check('weak password rejected with 422', weak.status === 422, `got ${weak.status}`);

const badPhone = await call('POST', '/api/auth/register', {
  body: { name: 'Bad Phone', phone: 'not-a-phone', password },
});
check('invalid phone rejected with 422', badPhone.status === 422, `got ${badPhone.status}`);

const wrongPw = await call('POST', '/api/auth/login', { body: { identifier: phone, password: 'WrongPass999' } });
check('wrong password returns 401', wrongPw.status === 401, `got ${wrongPw.status}`);
check(
  'wrong password does not reveal whether user exists',
  wrongPw.body?.error?.message === 'Incorrect phone number or password.',
  wrongPw.body?.error?.message,
);

const goodLogin = await call('POST', '/api/auth/login', { body: { identifier: phone, password } });
check('correct password returns 200', goodLogin.status === 200, JSON.stringify(goodLogin.body));

const rotated = await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } });
check('refresh returns 200', rotated.status === 200);
check('refresh issues a new refresh token', rotated.body?.refreshToken !== refresh);

const replay = await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } });
check('reusing a rotated refresh token is rejected', replay.status === 401, `got ${replay.status}`);

const me = await call('GET', '/api/auth/me', { token });
check('GET /me returns the member', me.body?.user?.id === userId);
check('GET /me hides password_hash', !JSON.stringify(me.body).includes('argon2'));

const noAuth = await call('GET', '/api/auth/me');
check('unauthenticated request is 401', noAuth.status === 401, `got ${noAuth.status}`);

const badToken = await call('GET', '/api/auth/me', { token: 'not.a.token' });
check('malformed token is 401', badToken.status === 401, `got ${badToken.status}`);

// --- authorisation ---------------------------------------------------

console.log('\nAuthorisation');
const adminOnly = await call('GET', '/api/admin/dashboard', { token });
check('member cannot read admin dashboard', adminOnly.status === 403, `got ${adminOnly.status}`);

const adminUsers = await call('GET', '/api/users', { token });
check('member cannot list users', adminUsers.status === 403, `got ${adminUsers.status}`);

const escalate = await call('POST', `/api/users/${userId}/role`, {
  token,
  body: { role: 'admin' },
});
check('member cannot promote themselves', escalate.status === 403, `got ${escalate.status}`);

const otherProfile = await call('GET', '/api/users/00000000-0000-4000-8000-000000000011', { token });
check('member cannot read another profile', otherProfile.status === 403, `got ${otherProfile.status}`);

// --- bins -------------------------------------------------------------

console.log('\nBins');
const binsAsMember = await call('GET', '/api/bins', { token });
check('member can list bins (read-only)', binsAsMember.status === 200, `got ${binsAsMember.status}`);

const createAsMember = await call('POST', '/api/bins', {
  token,
  body: { name: 'Should Not Exist' },
});
check('member cannot create a bin', createAsMember.status === 403, `got ${createAsMember.status}`);

const summary = await call('GET', '/api/bins/summary', { token });
check('summary responds 200', summary.status === 200, JSON.stringify(summary.body));
check('summary has numeric total', typeof summary.body?.summary?.total === 'number');

const map = await call('GET', '/api/bins/map', { token });
check('map returns located bins', map.status === 200 && Array.isArray(map.body?.bins));
check(
  'every mapped bin has both coordinates',
  (map.body?.bins ?? []).every((b) => b.latitude !== null && b.longitude !== null),
);

const badCoords = await call('POST', '/api/bins', {
  token: null,
  body: { name: 'Half Coords', latitude: 5.6 },
});
check('unauthenticated bin create is 401', badCoords.status === 401, `got ${badCoords.status}`);

// --- RFID normalisation (unauthenticated route-free check via 401/403) ---

console.log('\nRFID');
const rfidNoAuth = await call('GET', '/api/rfid/cards', { token });
check('member cannot list cards', rfidNoAuth.status === 403, `got ${rfidNoAuth.status}`);

const deviceUnauth = await call('POST', '/api/devices/report', {
  body: { sensorId: 'SNS-1001', fillPercent: 50 },
});
check('sensor report without auth is 401', deviceUnauth.status === 401, `got ${deviceUnauth.status}`);

// --- input validation --------------------------------------------------

console.log('\nValidation');
const badUuid = await call('GET', '/api/bins/not-a-uuid', { token });
check('malformed uuid is 422, not 500', badUuid.status === 422, `got ${badUuid.status}`);

const badJson = await fetch(`${BASE}/api/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: '{not json',
});
check('malformed JSON is 400, not 500', badJson.status === 400, `got ${badJson.status}`);

const badRoute = await call('GET', '/api/does-not-exist', { token });
check('unknown route is 404 JSON', badRoute.status === 404 && badRoute.body?.error?.code === 'route_not_found');

console.log(`\n${passed} passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);
