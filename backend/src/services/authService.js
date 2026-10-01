import crypto from 'node:crypto';
import argon2 from 'argon2';
import config from '../config.js';
import { one, query, withTransaction } from '../db.js';
import { AppError } from '../errors.js';
import { signAccessToken } from '../middleware/auth.js';

/**
 * Password hashing and refresh-token lifecycle.
 *
 * Two rules drive the design:
 *  1. Plaintext passwords never touch the database. Only an argon2id hash does.
 *  2. Refresh tokens are stored hashed, so a database leak (or a stolen
 *     backup) does not hand an attacker working sessions.
 */

/** @returns {Promise<string>} an argon2id hash, e.g. $argon2id$v=19$m=19456... */
export async function hashPassword(plain) {
  return argon2.hash(plain, {
    type: argon2.argon2id,
    memoryCost: config.auth.argon2.memoryCost,
    timeCost: config.auth.argon2.timeCost,
    parallelism: config.auth.argon2.parallelism,
  });
}

/**
 * Verify a password. Returns false on a malformed hash rather than throwing,
 * so a corrupt stored value cannot be turned into a 500.
 */
export async function verifyPassword(hash, plain) {
  if (!hash) {
    // Still spend the time: without this, a request for a passwordless account
    // returns instantly and reveals which accounts have passwords set.
    await argon2.hash(plain, { type: argon2.argon2id });
    return false;
  }
  try {
    return await argon2.verify(hash, plain);
  } catch {
    return false;
  }
}

/** Never store the token itself - only its SHA-256. */
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function newRefreshToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function expiryDate() {
  return new Date(Date.now() + config.auth.refreshTtlDays * 86_400_000);
}

/** Create a session and return the plaintext refresh token (shown once). */
export async function createSession(client, userId, { userAgent, ipAddress } = {}) {
  const token = newRefreshToken();
  const { rows } = await client.query(
    `insert into auth_sessions (user_id, refresh_hash, user_agent, ip_address, expires_at)
     values ($1, $2, $3, $4, $5)
     returning id`,
    [userId, hashToken(token), userAgent ?? null, ipAddress ?? null, expiryDate()],
  );
  return { sessionId: rows[0].id, refreshToken: token };
}

/**
 * Exchange a refresh token for a new pair, invalidating the old one.
 *
 * If a token that was already rotated comes back, either it was stolen or the
 * client is replaying. Either way every session for that user is revoked, so
 * the attacker's access dies with the legitimate user's next sign-in.
 */
export async function rotateSession(refreshToken, meta = {}) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `select id, user_id, state, expires_at
         from auth_sessions
        where refresh_hash = $1
        for update`,
      [hashToken(refreshToken)],
    );

    const session = rows[0];
    if (!session) throw AppError.unauthorized('Invalid session. Please sign in again.');

    if (session.state !== 'active') {
      await client.query(
        `update auth_sessions set state = 'revoked', revoked_at = now()
          where user_id = $1 and state = 'active'`,
        [session.user_id],
      );
      throw AppError.unauthorized('Session was already used. All sessions have been signed out.');
    }

    if (new Date(session.expires_at) < new Date()) {
      await client.query(
        `update auth_sessions set state = 'revoked', revoked_at = now() where id = $1`,
        [session.id],
      );
      throw AppError.unauthorized('Session expired. Please sign in again.');
    }

    await client.query(
      `update auth_sessions set state = 'rotated', revoked_at = now() where id = $1`,
      [session.id],
    );

    const next = await createSession(client, session.user_id, meta);

    const user = await one(
      `select id, name, nickname, phone, email, avatar_icon, role_id, points, bottles, weight_kg
         from users where id = $1`,
      [session.user_id],
    );
    if (!user) throw AppError.unauthorized('Account no longer exists.');
    if (user.account_state === 'disabled') {
      throw AppError.forbidden('This account has been disabled.');
    }

    return { user, refreshToken: next.refreshToken, accessToken: signAccessToken(user.id) };
  });
}

export async function revokeSession(refreshToken) {
  const { rowCount } = await query(
    `update auth_sessions set state = 'revoked', revoked_at = now()
      where refresh_hash = $1 and state = 'active'`,
    [hashToken(refreshToken)],
  );
  return rowCount > 0;
}

export async function revokeAllSessions(userId) {
  const { rowCount } = await query(
    `update auth_sessions set state = 'revoked', revoked_at = now()
      where user_id = $1 and state = 'active'`,
    [userId],
  );
  return rowCount;
}

/**
 * Verify credentials and apply lockout.
 *
 * Note the ordering: the account is locked *after* verifying the password, and
 * the failure counter only moves on a genuine wrong password. Otherwise
 * anyone could lock a member out by guessing their phone number.
 */
export async function authenticate(identifier, password) {
  const user = await one(
    `select id, name, nickname, phone, email, avatar_icon, role_id, account_state,
            password_hash, failed_login_count, locked_until
       from users
      where phone = $1 or email = lower($1)
      limit 1`,
    [identifier],
  );

  if (!user) {
    // Hash anyway so a missing account and a wrong password take the same
    // time, which stops the endpoint being used to enumerate phone numbers.
    await verifyPassword(null, password);
    throw AppError.invalidCredentials();
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    const minutes = Math.ceil((new Date(user.locked_until) - Date.now()) / 60_000);
    throw AppError.locked(`Too many failed attempts. Try again in ${minutes} minute(s).`);
  }

  const ok = await verifyPassword(user.password_hash, password);

  if (!ok) {
    const attempts = user.failed_login_count + 1;
    const lockFor = attempts >= 5 ? new Date(Date.now() + 15 * 60_000) : null;
    await query(
      `update users set failed_login_count = $2, locked_until = $3 where id = $1`,
      [user.id, lockFor ? 0 : attempts, lockFor],
    );
    throw AppError.invalidCredentials();
  }

  await query(
    `update users set failed_login_count = 0, locked_until = null, last_login_at = now()
      where id = $1`,
    [user.id],
  );

  if (user.account_state === 'disabled') {
    throw AppError.forbidden('This account has been disabled. Contact an administrator.');
  }

  return user;
}

export default {
  hashPassword,
  verifyPassword,
  createSession,
  rotateSession,
  revokeSession,
  revokeAllSessions,
  authenticate,
};
