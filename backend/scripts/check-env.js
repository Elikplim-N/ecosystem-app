/**
 * Check the environment and database before starting the server.
 *
 * Run this when something fails to start - it names the actual problem instead
 * of leaving you with a stack trace.
 *
 *   node scripts/check-env.js
 */
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const backendRoot = join(here, '..');

let failures = 0;
const ok = (m) => console.log(`  [ok]    ${m}`);
const bad = (m) => {
  console.log(`  [FAIL]  ${m}`);
  failures += 1;
};
const warn = (m) => console.log(`  [warn]  ${m}`);

console.log('\nEnvironment\n');

const envPath = join(backendRoot, '.env');
if (!existsSync(envPath)) {
  bad('.env is missing. Copy .env.example to .env first.');
} else {
  ok('.env exists');
}

// Parse .env by hand so this script can run even when config.js would exit.
const env = {};
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

for (const key of ['DATABASE_URL', 'JWT_SECRET', 'PORT']) {
  if (!env[key]) bad(`${key} is not set`);
  else ok(`${key} is set`);
}

if (env.JWT_SECRET) {
  if (env.JWT_SECRET.length < 32) bad('JWT_SECRET must be at least 32 characters.');
  else if (env.JWT_SECRET.includes('replace_me')) bad('JWT_SECRET is still the placeholder.');
  else ok(`JWT_SECRET looks real (${env.JWT_SECRET.length} chars)`);
}

console.log('\nDatabase\n');

const url = env.DATABASE_URL;
if (url) {
  if (/YOUR_PASSWORD|PLACEHOLDER|CHANGEME/i.test(url)) {
    bad('DATABASE_URL still contains a placeholder password.');
  } else {
    ok('DATABASE_URL has a password');

    let parsed;
    try {
      parsed = new URL(url);
      ok(`protocol ${parsed.protocol.replace(':', '')}`);
      ok(`host ${parsed.hostname}:${parsed.port || 5432}`);
      ok(`database ${parsed.pathname.slice(1)}`);
    } catch {
      bad('DATABASE_URL is not a valid URL');
    }

    const ssl = env.DB_SSL === 'true';
    const isProd = env.NODE_ENV === 'production';
    if (isProd && !ssl) bad('DB_SSL must be true in production.');
    else if (isProd) ok('DB_SSL is true');
    else warn('DB_SSL is false (fine for local development)');
  }
}

// Try an actual connection, but only if the URL looks usable.
if (url && !/YOUR_PASSWORD|PLACEHOLDER|CHANGEME/i.test(url) && !failures) {
  const { Pool } = await import('pg');
  const pool = new Pool({ connectionString: url, max: 1, connectionTimeoutMillis: 5000 });
  try {
    const result = await pool.query('select current_database() as db, version() as v');
    ok(`connected to "${result.rows[0].db}"`);
    const major = result.rows[0].v.match(/PostgreSQL (\d+)/)?.[1];
    if (Number(major) < 13) bad(`PostgreSQL ${major} is older than the 13 this schema targets.`);
    else ok(`PostgreSQL ${major}`);

    const tables = await pool.query(
      `select count(*)::int as n from information_schema.tables
        where table_schema = 'public' and table_type = 'BASE TABLE'`,
    );
    if (tables.rows[0].n === 0) {
      bad('no tables in the public schema. Run:  ..\\database\\setup.ps1 -Version 13');
    } else if (tables.rows[0].n < 15) {
      warn(`only ${tables.rows[0].n} tables found; expected 17. Re-run setup.ps1 -Recreate.`);
    } else {
      ok(`${tables.rows[0].n} tables present`);
    }

    const missing = await pool.query(
      `select count(*)::int as n from pg_proc p
        join pg_namespace ns on ns.oid = p.pronamespace
       where ns.nspname = 'public'
         and p.proname in ('apply_deposit_totals','log_bin_state_change','touch_updated_at','next_bin_code')`,
    );
    if (missing.rows[0].n < 4) bad('database functions are missing. Re-run schema.sql.');
    else ok('database functions present');
  } catch (err) {
    bad(`cannot connect: ${err.message}`);
  } finally {
    await pool.end();
  }
}

console.log(
  failures === 0
    ? '\nEverything checks out. Start the server with:  npm run dev\n'
    : `\n${failures} problem(s) found.\n`,
);
process.exit(failures === 0 ? 0 : 1);
