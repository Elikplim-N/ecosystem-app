/**
 * Give the seeded demo accounts a password so they can be signed into.
 *
 *   node scripts/set-seed-passwords.js              # prompts for a password
 *   node scripts/set-seed-passwords.js DevPass123!  # non-interactive
 *
 * DEVELOPMENT ONLY. This sets one shared password on every seeded account,
 * which must never happen on a real database - it would mean any admin,
 * ambassador and member account shares a login.
 */
import readline from 'node:readline';
import { closePool, query } from '../src/db.js';
import { hashPassword } from '../src/services/authService.js';
import config from '../src/config.js';

if (config.isProduction) {
  console.error('\nRefusing to run: NODE_ENV is "production".\n');
  process.exit(1);
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise((r) => rl.question(q, r));

console.log('\nThis sets the SAME password on all seeded accounts.');
console.log('Development only. Never run this on the server.\n');

const fromArgs = process.argv[2];
const plain = fromArgs ?? (await ask('Password for all seed accounts (min 8): ')).trim();

if (!plain || plain.length < 8) {
  console.error('Use at least 8 characters.');
  rl.close();
  await closePool();
  process.exit(1);
}

const confirm = fromArgs ?? (await ask('Confirm: ')).trim();
if (!fromArgs && plain !== confirm) {
  console.error('Passwords did not match.');
  rl.close();
  await closePool();
  process.exit(1);
}

const hash = await hashPassword(plain);

const result = await query(
  `update users
      set password_hash = $1,
          auth_provider = 'local',
          failed_login_count = 0,
          locked_until = null
    where phone like '+2332000%'
    returning name, phone, role_id`,
  [hash],
);

console.log(`\nUpdated ${result.rowCount} account(s):\n`);
for (const u of result.rows) {
  console.log(`  ${u.phone}  ${u.name.padEnd(16)} ${u.role_id}`);
}
console.log('\nSign in with any of those phone numbers.');

rl.close();
await closePool();
process.exit(0);
