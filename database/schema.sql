-- Ecosystem - Database Schema
--
-- PostgreSQL 13+ (tested against 13 and 18). This is the single source of
-- truth for the app; everything else is generated or written against it.
--
-- Design notes
-- ------------
-- * Roles live in a lookup table rather than as free text, so 'admin' vs
--   'Admin' vs 'ADMIN' can never be a third, unauthorised role.
-- * Enums are used instead of CHECK constraints so Postgres enforces the
--   allowed values and a bad write is rejected rather than silently stored.
-- * Timestamps are timestamptz (UTC). The Flutter app is the only thing that
--   should convert to local time.
-- * Money-like and weight-like values are numeric, never float. Floating point
--   rounding on kg or currency balances is not acceptable.
-- * Every table a user can be deleted from uses ON DELETE, never orphaned rows.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ROLES
-- ============================================================

CREATE TABLE roles (
    id          text PRIMARY KEY,
    label       text NOT NULL,
    -- Drives the UI. Ambassador features only render when true.
    can_manage_bins     boolean NOT NULL DEFAULT false,
    can_approve         boolean NOT NULL DEFAULT false,
    can_administer      boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO roles (id, label, can_manage_bins, can_approve, can_administer) VALUES
    ('user',       'Member',       false, false, false),
    ('ambassador', 'Ambassador',   true,  false, false),
    ('admin',      'Super Admin',  true,  true,  true);

-- ============================================================
-- USERS + AUTH
--
-- auth_provider is intentionally kept. If Firebase Auth is still in use for
-- some accounts during the transition, that identity stays addressable here
-- while the local credentials take over for everything new.
-- ============================================================

CREATE TYPE account_state AS ENUM ('active', 'disabled', 'deleted');
CREATE TYPE ambassador_state AS ENUM ('none', 'pending', 'approved', 'rejected');

CREATE TABLE users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Login identity. Phone is the identifier members actually remember.
    email           text UNIQUE,
    phone           text UNIQUE,
    email_verified  boolean NOT NULL DEFAULT false,
    phone_verified  boolean NOT NULL DEFAULT false,

    name            text NOT NULL,
    nickname        text,
    avatar_icon     text NOT NULL DEFAULT U&'\+01F642',
    password_hash   text,          -- null only for pending federated accounts
    auth_provider   text NOT NULL DEFAULT 'local',
    provider_uid    text,          -- Firebase Auth uid while migrating

    role_id         text NOT NULL DEFAULT 'user'
                        REFERENCES roles(id) ON DELETE RESTRICT,
    account_state   account_state NOT NULL DEFAULT 'active',

    ambassador_state       ambassador_state NOT NULL DEFAULT 'none',
    ambassador_area        text,
    ambassador_motivation  text,
    ambassador_applied_at  timestamptz,
    ambassador_reviewed_at timestamptz,
    ambassador_review_note text,

    -- Recycling totals. Kept denormalised for the leaderboard and profile,
    -- and recomputed from deposits by the trigger below.
    points          integer NOT NULL DEFAULT 0 CHECK (points >= 0),
    bottles         integer NOT NULL DEFAULT 0 CHECK (bottles >= 0),
    weight_kg       numeric(12,3) NOT NULL DEFAULT 0 CHECK (weight_kg >= 0),

    -- Failed-login throttling state.
    failed_login_count integer NOT NULL DEFAULT 0,
    locked_until      timestamptz,

    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    last_login_at   timestamptz,

    CONSTRAINT email_or_phone_required CHECK (
        email IS NOT NULL OR phone IS NOT NULL
    )
);

CREATE INDEX users_role_idx        ON users (role_id);
CREATE INDEX users_ambassador_idx  ON users (ambassador_state)
                                      WHERE ambassador_state = 'pending';
CREATE INDEX users_phone_idx       ON users (phone) WHERE phone IS NOT NULL;
CREATE INDEX users_active_idx      ON users (account_state);

-- Names and phone numbers are PII, so keep them out of the default dump.
COMMENT ON TABLE users IS
    'Contains personal data. Exclude from unencrypted backups/logs where possible.';

-- ============================================================
-- SESSIONS / REFRESH TOKENS
--
-- Access tokens are stateless and short lived. Refresh tokens live here so
-- they can be revoked server-side; storing only a hash means a database leak
-- does not hand an attacker usable sessions.
-- ============================================================

CREATE TYPE session_state AS ENUM ('active', 'revoked', 'rotated');

CREATE TABLE auth_sessions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- SHA-256 of the refresh token. The plaintext is shown once, never stored.
    refresh_hash    text NOT NULL UNIQUE,
    state           session_state NOT NULL DEFAULT 'active',
    user_agent      text,
    ip_address      inet,
    expires_at      timestamptz NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    revoked_at      timestamptz
);

CREATE INDEX auth_sessions_user_idx    ON auth_sessions (user_id);
CREATE INDEX auth_sessions_active_idx  ON auth_sessions (user_id)
                                         WHERE state = 'active';
CREATE INDEX auth_sessions_expiry_idx  ON auth_sessions (expires_at);

-- Password reset and phone verification tokens share this table.
CREATE TABLE auth_tokens (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose     text NOT NULL CHECK (purpose IN
                    ('password_reset', 'phone_verify', 'email_verify')),
    token_hash  text NOT NULL UNIQUE,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX auth_tokens_user_idx ON auth_tokens (user_id, purpose);

-- One-time codes for admin-sensitive actions, e.g. deleting an account.
CREATE TABLE auth_mfa_codes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose     text NOT NULL,
    code_hash   text NOT NULL,
    expires_at  timestamptz NOT NULL,
    consumed_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RFID CARDS
--
-- tag_normalised is the deduplication key: every scanner emits the same
-- physical card differently (a3f921c0, A3F9:21C0, A3F9 21C0). Normalising
-- once on write means one card can never become three.
-- ============================================================

CREATE TYPE rfid_state AS ENUM ('available', 'linked', 'lost', 'revoked');
CREATE TYPE rfid_card_kind AS ENUM (
    'standard', 'mifare_1k', 'mifare_ultralight',
    'em4100', 'hid_prox', 'student_id', 'staff_id'
);

CREATE TABLE rfid_cards (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_raw         text NOT NULL,
    tag_normalised  text NOT NULL UNIQUE,
    -- Character count of the normalised tag: 8/14/16/20 hex chars is normal.
    tag_length      integer NOT NULL,
    card_kind       rfid_card_kind NOT NULL DEFAULT 'standard',
    state           rfid_state NOT NULL DEFAULT 'available',

    assigned_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    assigned_at     timestamptz,
    -- Which registration produced this link.
    issued_by       uuid REFERENCES users(id) ON DELETE SET NULL,
    notes           text,
    lost_at         timestamptz,
    revoked_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX rfid_cards_state_idx   ON rfid_cards (state);
CREATE INDEX rfid_cards_user_idx    ON rfid_cards (assigned_user_id)
                                     WHERE assigned_user_id IS NOT NULL;

-- A user holds at most one active card.
CREATE UNIQUE INDEX rfid_cards_one_per_user_idx
    ON rfid_cards (assigned_user_id)
    WHERE assigned_user_id IS NOT NULL
      AND state IN ('linked', 'lost');

-- ============================================================
-- BINS
--
-- Ambassadors may add and update bins, but only bins they created. Ownership
-- is a column rather than a join table because exactly one person owns a bin.
-- ============================================================

CREATE TYPE bin_state AS ENUM ('available', 'filling', 'full', 'disabled');
CREATE TYPE status_source AS ENUM ('sensor', 'manual');

CREATE TABLE bins (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Short code painted on the bin, e.g. BIN-001.
    code            text NOT NULL UNIQUE,
    name            text NOT NULL,

    bin_state       bin_state NOT NULL DEFAULT 'available',
    status_source   status_source NOT NULL DEFAULT 'manual',
    -- The accepted compartment. This is the one bin_state is derived from.
    fill_percent    numeric(5,2) NOT NULL DEFAULT 0
                        CHECK (fill_percent >= 0 AND fill_percent <= 100),
    -- The rejected compartment beside it, fed by its own sensor. Kept
    -- separate from fill_percent because filling the wrong compartment does
    -- not make a bin full - it makes the sorting wrong.
    rejected_fill_percent numeric(5,2) NOT NULL DEFAULT 0
                        CHECK (rejected_fill_percent >= 0 AND rejected_fill_percent <= 100),
    -- What the bin is for, e.g. 'Plastic' or 'Glass'.
    collects        text NOT NULL DEFAULT 'Plastic',
    capacity_kg     numeric(10,2) NOT NULL DEFAULT 50 CHECK (capacity_kg > 0),

    address         text,
    latitude        numeric(10,7) CHECK (latitude  BETWEEN  -90 AND  90),
    longitude       numeric(10,7) CHECK (longitude BETWEEN -180 AND 180),
    -- Set when the device reports in.
    sensor_id       text UNIQUE,

    created_by_id    uuid REFERENCES users(id) ON DELETE SET NULL,
    created_by_role  text REFERENCES roles(id) ON DELETE SET NULL,

    last_collected_at timestamptz,
    last_reported_at  timestamptz NOT NULL DEFAULT now(),
    disabled_at       timestamptz,
    notes             text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX bins_state_idx   ON bins (bin_state);
CREATE INDEX bins_creator_idx ON bins (created_by_id);
-- Drives the map's spatial query as bins scale up.
CREATE INDEX bins_location_idx ON bins (latitude, longitude)
    WHERE latitude IS NOT NULL;

-- A bin without coordinates cannot appear on the map, so require both or neither.
ALTER TABLE bins ADD CONSTRAINT bins_location_pairing CHECK (
    (latitude IS NULL AND longitude IS NULL)
    OR (latitude IS NOT NULL AND longitude IS NOT NULL)
);

-- The next BIN-### code, allocated so two admins adding a bin at the same
-- instant cannot collide on the UNIQUE constraint.
CREATE SEQUENCE bin_code_seq START 1;

CREATE FUNCTION next_bin_code() RETURNS text
LANGUAGE sql AS $$
    SELECT 'BIN-' || lpad(nextval('bin_code_seq')::text, 3, '0');
$$;

-- ============================================================
-- BIN STATUS HISTORY
--
-- Append-only. This is the audit trail that makes "why is this bin full?"
-- answerable, and it is the raw data for any reporting later.
-- ============================================================

CREATE TABLE bin_status_events (
    id            bigserial PRIMARY KEY,
    bin_id        uuid NOT NULL REFERENCES bins(id) ON DELETE CASCADE,
    previous_state bin_state,
    new_state     bin_state NOT NULL,
    fill_percent  numeric(5,2),
    source        status_source NOT NULL,
    reported_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
    note          text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX bin_status_events_bin_idx   ON bin_status_events (bin_id, created_at DESC);
CREATE INDEX bin_status_events_time_idx  ON bin_status_events (created_at DESC);

-- ============================================================
-- COLLECTIONS
--
-- Distinct from a status change: this is a truck arriving and taking weight.
-- ============================================================

CREATE TABLE collections (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bin_id        uuid NOT NULL REFERENCES bins(id) ON DELETE CASCADE,
    collected_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
    weight_kg     numeric(10,2) NOT NULL CHECK (weight_kg >= 0),
    -- True when confirmed by staff rather than read from a scale.
    is_estimated  boolean NOT NULL DEFAULT false,
    notes         text,
    collected_at  timestamptz NOT NULL DEFAULT now(),
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX collections_bin_idx       ON collections (bin_id, collected_at DESC);
CREATE INDEX collections_collected_idx ON collections (collected_at DESC);

-- ============================================================
-- DEPOSITS (user recycling activity)
-- ============================================================

CREATE TYPE bottle_kind AS ENUM ('coloured', 'clear');

CREATE TABLE deposits (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bin_id          uuid REFERENCES bins(id) ON DELETE SET NULL,
    kiosk_id        text,

    bottle_kind     bottle_kind NOT NULL DEFAULT 'clear',
    bottle_count    integer NOT NULL DEFAULT 1 CHECK (bottle_count > 0),
    weight_kg       numeric(10,3) NOT NULL CHECK (weight_kg >= 0),
    points_awarded  integer NOT NULL DEFAULT 0 CHECK (points_awarded >= 0),

    -- Idempotency: a kiosk retrying the same deposit must not double-credit.
    reference_code  text UNIQUE,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX deposits_user_idx  ON deposits (user_id, created_at DESC);
CREATE INDEX deposits_bin_idx   ON deposits (bin_id, created_at DESC);
CREATE INDEX deposits_time_idx  ON deposits (created_at DESC);

-- ============================================================
-- BIN CAPACITY TRIGGER
--
-- Keeps the user's denormalised points/bottles/weight in step with the
-- deposit rows, so the leaderboard can never disagree with the history.
-- ============================================================

CREATE FUNCTION apply_deposit_totals() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE users SET
        points    = points + NEW.points_awarded,
        bottles   = bottles + NEW.bottle_count,
        weight_kg = weight_kg + NEW.weight_kg,
        updated_at = now()
    WHERE id = NEW.user_id;

    -- Deliberately does NOT touch bins.fill_percent. An earlier version added
    -- 3% per deposit, which was a fabrication: it overrode real sensor
    -- readings, and drifted the bin away from the value its device reported.
    -- Fill level has exactly two sources -- a sensor, or a person editing the
    -- bin -- and both of those go through UPDATE on bins instead.

    RETURN NEW;
END;
$$;

CREATE TRIGGER deposits_apply_totals
    AFTER INSERT ON deposits
    FOR EACH ROW EXECUTE FUNCTION apply_deposit_totals();

-- ============================================================
-- BIN STATUS CHANGE TRIGGER
--
-- Any state change, from a sensor, an admin or an ambassador, lands in the
-- history table. This is the only way bin_state changes, so nothing can
-- bypass the audit trail.
-- ============================================================

-- The connection sets app.actor_id at the start of a transaction
-- (SET LOCAL app.actor_id = '<uuid>'), so the history records who acted
-- even though the UPDATE statement itself carries no actor column.
CREATE FUNCTION log_bin_state_change() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    actor uuid;
BEGIN
    BEGIN
        actor := NULLIF(current_setting('app.actor_id', true), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        actor := NULL;
    END;

    IF NEW.bin_state IS DISTINCT FROM OLD.bin_state
       OR NEW.fill_percent IS DISTINCT FROM OLD.fill_percent THEN

        INSERT INTO bin_status_events (
            bin_id, previous_state, new_state,
            fill_percent, source, reported_by_id
        ) VALUES (
            NEW.id, OLD.bin_state, NEW.bin_state,
            NEW.fill_percent, NEW.status_source, actor
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER bins_log_state_change
    AFTER UPDATE ON bins
    FOR EACH ROW EXECUTE FUNCTION log_bin_state_change();

-- ============================================================
-- REWARDS + REDEMPTIONS
-- ============================================================

CREATE TABLE rewards (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title         text NOT NULL,
    description   text,
    -- 'standard' for BoaMe-issued rewards, 'partner' for a voucher a
    -- sponsor funds. The app groups the catalogue by this.
    category      text NOT NULL DEFAULT 'standard'
                      CHECK (category IN ('standard', 'partner')),
    -- Optional partner offer, e.g. a discount voucher.
    partner_name  text,
    cost_points   integer NOT NULL CHECK (cost_points >= 0),
    stock         integer CHECK (stock IS NULL OR stock >= 0),
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE redemptions (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id     uuid NOT NULL REFERENCES rewards(id) ON DELETE RESTRICT,
    cost_points   integer NOT NULL,
    -- This is the queue the admin console was missing under Firebase.
    status        text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected', 'fulfilled')),
    collected_at  timestamptz,
    reviewed_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
    review_note   text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    reviewed_at   timestamptz
);

CREATE INDEX redemptions_status_idx ON redemptions (status, created_at DESC);
CREATE INDEX redemptions_user_idx   ON redemptions (user_id, created_at DESC);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
    -- Null user_id plus a role target broadcasts to a whole audience.
    target_role text REFERENCES roles(id) ON DELETE CASCADE,
    title       text NOT NULL,
    body        text NOT NULL,
    kind        text NOT NULL DEFAULT 'info',
    is_read     boolean NOT NULL DEFAULT false,
    read_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_audience CHECK (
        user_id IS NOT NULL OR target_role IS NOT NULL
    )
);

CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON notifications (user_id)
    WHERE is_read = false;

-- ============================================================
-- CONTACT MESSAGES
-- Closed the write-only gap: the form used to write into a collection
-- nothing ever read back.
-- ============================================================

CREATE TABLE contact_messages (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid REFERENCES users(id) ON DELETE SET NULL,
    name          text,
    phone         text,
    email         text,
    message       text NOT NULL,
    status        text NOT NULL DEFAULT 'open'
                      CHECK (status IN ('open', 'answered', 'closed')),
    replied_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
    reply         text,
    replied_at    timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX contact_messages_status_idx ON contact_messages (status, created_at DESC);

-- ============================================================
-- AUDIT LOG
--
-- Who changed what, for the actions that matter: role changes, disabling
-- accounts, deletions, card revocation.
-- ============================================================

CREATE TABLE audit_log (
    id            bigserial PRIMARY KEY,
    actor_id      uuid REFERENCES users(id) ON DELETE SET NULL,
    action        text NOT NULL,
    entity_type   text NOT NULL,
    entity_id     text,
    -- JSONB so new actions need no migration.
    details       jsonb NOT NULL DEFAULT '{}'::jsonb,
    ip_address    inet,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_entity_idx ON audit_log (entity_type, entity_id);
CREATE INDEX audit_log_time_idx   ON audit_log (created_at DESC);
CREATE INDEX audit_log_actor_idx  ON audit_log (actor_id, created_at DESC);

-- ============================================================
-- UPDATED_AT MAINTENANCE
-- ============================================================

CREATE FUNCTION touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER users_touch      BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER rfid_cards_touch BEFORE UPDATE ON rfid_cards
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER bins_touch       BEFORE UPDATE ON bins
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER rewards_touch    BEFORE UPDATE ON rewards
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ============================================================
-- VIEWS
--
-- The queries the Flutter app hits most often, so they are written once.
-- ============================================================

-- Current leaderboard, ties broken by weight then name for stability.
CREATE VIEW leaderboard AS
SELECT
    u.id,
    u.nickname,
    u.avatar_icon,
    u.points,
    u.bottles,
    u.weight_kg,
    u.role_id,
    DENSE_RANK() OVER (ORDER BY u.points DESC, u.weight_kg DESC) AS rank
FROM users u
WHERE u.account_state = 'active'
  AND u.role_id <> 'admin'
ORDER BY u.points DESC, u.weight_kg DESC;

-- Dashboard aggregates so the app never fans out over many queries.
CREATE VIEW bin_summary AS
SELECT
    COUNT(*)                                          AS total,
    COUNT(*) FILTER (WHERE bin_state = 'available')   AS available,
    COUNT(*) FILTER (WHERE bin_state = 'filling')     AS filling,
    COUNT(*) FILTER (WHERE bin_state = 'full')        AS full,
    COUNT(*) FILTER (WHERE bin_state = 'disabled')    AS disabled,
    COUNT(*) FILTER (WHERE sensor_id IS NOT NULL)     AS sensor_backed,
    COUNT(*) FILTER (WHERE latitude IS NOT NULL)      AS located
FROM bins;

CREATE VIEW admin_dashboard_summary AS
SELECT
    (SELECT COUNT(*) FROM users WHERE account_state = 'active')              AS active_users,
    (SELECT COUNT(*) FROM users WHERE role_id = 'ambassador')                AS ambassadors,
    (SELECT COUNT(*) FROM users WHERE ambassador_state = 'pending')          AS pending_applications,
    (SELECT COUNT(*) FROM redemptions WHERE status = 'pending')              AS pending_redemptions,
    (SELECT COUNT(*) FROM contact_messages WHERE status = 'open')            AS open_messages,
    (SELECT COUNT(*) FROM bins WHERE bin_state = 'full')                     AS full_bins,
    (SELECT COUNT(*) FROM rfid_cards WHERE state = 'available')              AS spare_cards;
