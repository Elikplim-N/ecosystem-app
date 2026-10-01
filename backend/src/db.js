import pg from 'pg';
import config from './config.js';

const { Pool } = pg;

/**
 * Postgres keeps NUMERIC as a string so precision is never lost in JS.
 * That is correct for money and weight, but `numeric` columns that the UI
 * treats as plain numbers (fill_percent, weight_kg) come back as '95.00'.
 * Parsing them here keeps that concern out of every route.
 */
pg.types.setTypeParser(1700, (v) => (v === null ? null : Number.parseFloat(v))); // numeric
pg.types.setTypeParser(20, (v) => (v === null ? null : Number.parseInt(v, 10))); // int8/bigint

export const pool = new Pool({
  connectionString: config.db.url,
  max: config.db.poolMax,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
  ssl: config.db.ssl ? { rejectUnauthorized: false } : false,
});

pool.on('error', (err) => {
  // An idle client died (server restart, network blip). The pool discards it;
  // logging keeps it from being silent.
  console.error('[db] idle client error:', err.message);
});

/** Run a single query. Always parameterised - never build SQL by hand. */
export async function query(text, params) {
  const started = Date.now();
  const result = await pool.query(text, params);
  if (config.logLevel === 'debug') {
    console.log(`[db] ${Date.now() - started}ms ${text.trim().split('\n')[0]}`);
  }
  return result;
}

/** First row, or null. */
export async function one(text, params) {
  const { rows } = await query(text, params);
  return rows[0] ?? null;
}

/** All rows. */
export async function many(text, params) {
  const { rows } = await query(text, params);
  return rows;
}

/**
 * Run `fn` inside a transaction, rolling back on any throw.
 *
 * This is what makes multi-table operations atomic: approving an ambassador
 * updates users and writes an audit row, and if the audit write fails neither
 * change should survive.
 */
export async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Connection already gone; nothing useful to do.
    }
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Run `fn` inside a transaction that also tells the database who is acting.
 *
 * The bin status trigger reads app.actor_id to fill in reported_by_id, so
 * every audit row gets an actor without the UPDATE statement having to carry
 * one. set_config is parameterised, so the actor id can never be injected.
 */
export async function withActor(actorId, fn) {
  return withTransaction(async (client) => {
    if (actorId) {
      await client.query('select set_config($1, $2, true)', ['app.actor_id', actorId]);
    }
    return fn(client);
  });
}

/**
 * Translate Postgres error codes into something meaningful.
 * Called by the error handler, not by routes.
 */
export function describePgError(err) {
  switch (err.code) {
    case '23505': // unique_violation
      return { status: 409, message: 'That value is already taken.', detail: err.constraint };
    case '23503': // foreign_key_violation
      return { status: 400, message: 'Referenced record does not exist.', detail: err.constraint };
    case '23514': // check_violation
      return { status: 400, message: 'A value was outside the allowed range.', detail: err.constraint };
    case '22P02': // invalid_text_representation
      return { status: 400, message: 'Malformed identifier.', detail: err.column };
    case '57014': // query_canceled (statement timeout)
      return { status: 503, message: 'The database took too long to respond.', detail: null };
    default:
      return null;
  }
}

export async function closePool() {
  await pool.end();
}

export default { pool, query, one, many, withTransaction, withActor, closePool };
