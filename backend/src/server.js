import config from './config.js';
import { createApp } from './app.js';
import { closePool, query } from './db.js';

const app = createApp();

/**
 * Verify the database is reachable BEFORE binding the port. A server that
 * starts and then 500s on every request is far harder to diagnose than one
 * that refuses to start.
 */
async function verifyDatabase() {
  const row = await query('select current_database() as db, version() as version');
  const short = row.rows[0].version.split(' ').slice(0, 2).join(' ');
  console.log(`[db] connected to "${row.rows[0].db}" (${short})`);
}

let server;

try {
  await verifyDatabase();
} catch (err) {
  console.error('\n[db] Could not connect. Is Postgres running, and DATABASE_URL correct?\n');
  console.error(`      ${err.message}\n`);
  console.error('      Run:  node scripts/check-env.js\n');
  await closePool().catch(() => {});
  process.exit(1);
}

server = app.listen(config.port, () => {
  console.log(`\n  Ecosystem API`);
  console.log(`  http://localhost:${config.port}`);
  console.log(`  health:  http://localhost:${config.port}/health`);
  console.log(`  env:     ${config.env}`);
  console.log(`  log:     ${config.logLevel}\n`);
});

let shuttingDown = false;

/**
 * Graceful shutdown: stop accepting connections, let in-flight requests finish,
 * then close the pool. Without this, a deploy can cut a request off mid-write.
 */
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`\n[${signal}] shutting down...`);

  const force = setTimeout(() => {
    console.error('Forcing exit after 10s.');
    process.exit(1);
  }, 10_000);
  force.unref();

  server.close(async () => {
    try {
      await closePool();
      console.log('[db] pool closed.');
    } catch (err) {
      console.error('[db] error closing pool:', err.message);
    }
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

process.on('unhandledRejection', (reason) => {
  console.error('[fatal] unhandled promise rejection:', reason);
  shutdown('unhandledRejection');
});
