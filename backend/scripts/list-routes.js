/**
 * List every registered endpoint with its HTTP method and required roles.
 *
 *   node scripts/list-routes.js
 *
 * Useful as the API reference while the Flutter app is being wired up.
 */
import { ROUTE_MODULES, createApp } from '../src/app.js';

const app = createApp();
const rows = [];

// Walk each router with the prefix Express actually mounted it at, taken from
// ROUTE_MODULES. Reading the prefix from the mount list rather than from the
// compiled regexp avoids the escaping problem entirely.
function walkRouter(router, prefix) {
  for (const layer of router.stack ?? []) {
    if (layer.route) {
      for (const method of Object.keys(layer.route.methods)) {
        if (method === '_all') continue;
        rows.push({ method: method.toUpperCase(), path: prefix + layer.route.path });
      }
    } else if (layer.name === 'router' && layer.handle?.stack) {
      const segment = layer.regexp?.source?.match(/\\\/([A-Za-z0-9_:]+)/)?.[1];
      walkRouter(layer.handle, segment ? `${prefix}/${segment}` : prefix);
    }
  }
}

for (const [prefix, router] of ROUTE_MODULES) {
  walkRouter(router, prefix);
}

rows.sort((a, b) => a.path.localeCompare(b.path) || a.method.localeCompare(b.method));

// Reading aid only. The real authorisation lives in each route's middleware.
function authHint(path) {
  if (path.startsWith('/health')) return 'public';
  if (path.startsWith('/api/auth')) {
    return path.includes('me') || path.includes('logout') ? 'session' : 'public';
  }
  if (path.startsWith('/api/admin')) return 'admin';
  if (path.startsWith('/api/contact')) {
    return path.includes('/me') ? 'session' : 'public or session';
  }
  if (path.startsWith('/api/devices')) return path.endsWith('/bins') ? 'public' : 'sensor token';
  if (path.startsWith('/api/rfid')) return 'admin';
  // The rewards catalogue admin view, which is not under /api/admin.
  if (path.startsWith('/api/rewards/admin')) return 'admin';
  // Order matters: a member's own /me/redemptions is not an admin endpoint.
  if (path.includes('/me/')) return 'session (own)';
  if (path.includes('/redemptions') || path.includes('/applications')) return 'admin';
  return 'session';
}

console.log('\n  METHOD  PATH                                    AUTH\n');
console.log(`  ${'-'.repeat(62)}\n`);
for (const r of rows) {
  console.log(`  ${r.method.padEnd(7)}${r.path.padEnd(41)}${authHint(r.path)}`);
}
console.log(`\n  ${rows.length} endpoints\n`);
