# Ecosystem API

Express + Postgres backend. Replaces Firebase entirely — no Firestore, no
Firebase Auth.

JavaScript (ESM) on Node 20+. Uses raw parameterised SQL against
`node-postgres`, deliberately **not** an ORM: this schema relies on database
triggers and views (the audit trail, derived totals, the leaderboard), and an
ORM would hide them behind a layer where nobody can see they exist.

## Status

Everything below is written and syntax-checked. It has **not** been run against
the live database yet, because that needs the password in `.env`.

| Area | State |
|---|---|
| 50 REST endpoints | written |
| Argon2id auth + refresh rotation | written |
| RBAC (user / ambassador / admin) | written |
| Bin CRUD, status, collections | written |
| RFID registry | written |
| Ambassador application + review | written |
| Rewards, redemptions, admin queues | written |
| Sensor ingestion | written (transport still undecided) |
| Smoke test | written, not yet run |
| Flutter app pointing at it | **not started** — app still uses Firebase |

## Setup

```powershell
cd C:\Users\ASUS\OneDrive\Desktop\Boame\ecosystem-app\backend

# 1. Dependencies
npm install

# 2. Configuration - put your real Postgres password in here
Copy-Item .env.example .env
```

Edit `.env`:

```
DATABASE_URL=postgresql://postgres:YOUR_REAL_PASSWORD@localhost:5433/ecosystem
JWT_SECRET=<64 hex characters>
```

Generate a JWT secret:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Note the port: **`ecosystem` lives on Postgres 13, which is port 5433.** Postgres
18 is on 5432 and has a different password.

Then:

```powershell
# 3. Verify everything before starting
npm run check

# 4. Give the demo accounts a password (development only)
npm run seed:passwords

# 5. Run it
npm run dev
```

In a second terminal:

```powershell
node scripts/smoke-test.js
```

## Endpoints

| Group | Base | Auth |
|---|---|---|
| Health | `/health` | none |
| Auth | `/api/auth` | mixed |
| Users | `/api/users` | member or admin |
| Bins | `/api/bins` | member read, admin/ambassador write |
| RFID | `/api/rfid` | admin |
| Ambassador | `/api/ambassador` | member apply, admin review |
| Rewards | `/api/rewards` | member redeem, admin review |
| Admin | `/api/admin` | admin |
| Devices | `/api/devices` | sensor token |

Full list: `node scripts/list-routes.js`.

### The ones that matter most

```
POST /api/auth/register     name, phone, password
POST /api/auth/login        identifier (phone or email), password
POST /api/auth/refresh      rotates the refresh token
GET  /api/bins              ?state=&mine=&search=
POST /api/bins              admin or ambassador
POST /api/bins/:id/status   fillPercent -> state is derived, not accepted
POST /api/bins/:id/collect  records weight; resets fill
POST /api/rfid/cards        tag normalised; duplicates rejected by the DB
POST /api/ambassador/apply  area, motivation
POST /api/ambassador/applications/:id/review   approve | reject
POST /api/devices/report    sensorId, fillPercent
```

## Security decisions worth knowing

**Passwords are argon2id.** OWASP's recommended cost parameters live in `.env`.
Not bcrypt, not SHA-256.

**Refresh tokens are stored hashed** (SHA-256) and rotate on every use. If an
already-rotated token is presented again, that means replay or theft, so
*every* session for that user is revoked.

**The access token carries only a user id.** Role and account state are
re-read from the database on every request, which costs one indexed lookup and
means disabling an account takes effect immediately rather than whenever the
old token happens to expire.

**Disabling an account revokes its sessions.** Otherwise "disabled" would only
stop working once the token aged out.

**Login does not reveal whether an account exists.** A missing account still
pays the cost of an argon2 verification, so response timing does not leak
whether a phone number is registered.

**Bin state is never accepted from the client.** Routes take `fillPercent` and
derive `available` / `filling` / `full` themselves (`src/lib/bins.js`). A sensor
and a human editing the same bin cannot disagree about the rule.

**RFID duplicates are prevented by a `UNIQUE` constraint**, not by application
logic. `src/lib/rfid.js` normalises the tag first, but the database is what
actually guarantees one card is one row.

**Ambassadors can only edit bins they created** (`assertCanEditBin`). If the
team decides they should manage their whole area instead, that is the one
function to change.

**SQLite-style string interpolation does not exist here.** Every query is
parameterised. `withActor()` passes the acting user through
`set_config('app.actor_id', $1, true)` so the audit trigger fills in
`reported_by_id` without any string concatenation.

**Unknown errors become a generic 500.** A raw `pg` error can contain table
names and query fragments; those are logged server-side and never returned.

## Known gaps

1. **Password reset is not implemented.** `auth_tokens` has the table and the
   purpose enum, but there is no email/SMS provider wired up, so there is
   nowhere to send a code. This is the last blocking piece of auth and it
   needs a provider decision.

2. **Sensor auth is currently just the sensor id.** `POST /api/devices/report`
   checks `Authorization: Bearer <sensorId>`, which is weak. Replace with a
   per-sensor secret before the hardware ships. The comment in
   `src/routes/devices.routes.js` marks this.

3. **There is no migration runner.** `schema.sql` is applied directly. Once the
   schema starts changing after launch, add something like node-pg-migrate or
   Flyway — do not keep re-running schema.sql.

4. **No automated test suite yet.** `scripts/smoke-test.js` covers the critical
   paths end to end; it should become `node:test` unit tests as it grows.

5. **Rate limiting is per IP and in-memory.** Fine for one instance. Behind
   more than one instance you need a shared store (Redis), or the limits drift
   per process.

6. **`users` is not yet soft-delete cleaned up.** `account_state = 'deleted'`
   works and access is revoked, but no scheduled job anonymises the personal
   data as promised to the user.

## Deploying to the cloud server

The shape is one `docker-compose.yml` with three services: `api`, `postgres`,
and Caddy for TLS. That is not written yet — do it once the Flutter app is
talking to this and you know what you actually need.

Checklist before it goes live:

- [ ] Create a **non-superuser** database role for the API. The app must not
      connect as `postgres`.
- [ ] `DB_SSL=true`, `NODE_ENV=production`
- [ ] `CORS_ORIGINS` set to the real web origin
- [ ] `JWT_SECRET` generated fresh on the server
- [ ] Nightly `pg_dump`, and **test a restore**
- [ ] `users` holds names, phone numbers and bin locations. Restrict backups
      and never log query parameters.
