# Database & Backend

Postgres schema for the Ecosystem app. This replaces Firebase (Firestore +
Firebase Auth) with a database you host yourself on the team lead's cloud
server.

## Status

| Area | State |
|---|---|
| Postgres schema | **Written, not yet applied** — needs the DB password |
| Seed data | Written, not yet applied |
| Auth | Schema ready (sessions, refresh tokens, resets). API code **on hold** — you put the language decision off |
| Device/sensor ingestion | Deliberately undecided. Schema already supports it |
| Flutter data layer | Still Firestore. `BinsRepository` / `UserRepository` are the seam a Postgres client replaces |

Local clusters on this machine — note the port does **not** follow the version:

| Version | Port | Status |
|---|---|---|
| 18 | 5432 | running |
| 13 | 5433 | running, **this is where `ecosystem` lives** |

Both scripts read the real port from `postmaster.pid`, so you never need to pass
`-Port` unless a cluster is stopped. Pick the cluster with `-Version`:

```powershell
cd database
.\setup.ps1 -Version 13        # port 5433, where ecosystem already exists
.\setup.ps1 -Version 13 -Recreate   # drop everything and start clean
```

To apply the schema by hand instead:

```powershell
$env:PGPASSWORD = 'your-superuser-password'
& "C:\Program Files\PostgreSQL\13\bin\psql.exe" -h localhost -p 5433 -U postgres -d ecosystem -v ON_ERROR_STOP=1 -f schema.sql
```

Forgotten the password? It cannot be read back — PostgreSQL keeps only a SCRAM
hash. Run `.\reset-password.ps1 -Version 13`.

`verify.sql` prints expected row counts for every table and ends with three
queries that **must return zero rows** (RFID duplicates, orphaned bin
coordinates, users holding two cards). If those are non-empty, something is
wrong.

To start completely fresh on a dev database:

```sql
DROP SCHEMA public CASCADE; CREATE SCHEMA public;
```

That deletes everything. Do not run it against the server.

## What is enforced by the database, not just the app

This is the important part. Under Firestore the rules were client-side, so any
user could have written to any collection. Constraints here hold regardless of
what the Flutter app does:

- **Roles are a lookup table.** `user` / `ambassador` / `admin`. Free text like
  `'Admin'` cannot be stored, so permissions checks have one known set of values.
- **RFID cards cannot duplicate.** `tag_normalised` is `UNIQUE`. The app
  normalises `a3f9:21c0`, `A3F9 21C0` and `A3F9-21C0` to the same value, so one
  physical card is always one row.
- **One active card per user** — partial unique index on `assigned_user_id`.
- **Bins need both coordinates or neither** — a bin with only latitude cannot
  appear on the map, so the partial state is rejected.
- **`fill_percent` is 0–100** and `capacity_kg > 0`.
- **Money and weight are `numeric`, never float.** Float rounding on kg or
  point balances is not acceptable.
- **Deposits are idempotent** via `reference_code`, so a kiosk that retries
  cannot double-credit a member.
- **Every bin status change is recorded** in `bin_status_events` by a trigger.
  Nothing can change a bin's state without leaving an audit trail.
- **User totals are derived**, not trusted. The `deposits_apply_totals` trigger
  recomputes points/bottles/weight, so the leaderboard can never disagree with
  the deposit history.

## Auth design (custom, per your answer)

Dropping Firebase Auth means owning password security. The schema is built for:

- **Argon2id** password hashing (not bcrypt, not a plain hash).
- **Short-lived access tokens** (15 min) + **rotating refresh tokens** (30 days).
- Refresh tokens are stored **hashed**, so a database leak does not yield usable
  sessions, and they can be revoked server-side.
- Failed-login throttling via `users.failed_login_count` / `locked_until`.
- Password reset and phone verification tokens in `auth_tokens`.
- `users.auth_provider` / `provider_uid` are retained so accounts can be
  migrated from Firebase Auth without losing identity.

**The dependency you will need:** password reset requires sending email or SMS.
That is a new piece of infrastructure — pick a provider (e.g. a transactional
email API) before shipping registration. Right now `SMTP_*` in `.env.example` is
empty on purpose.

## Ambassadors and bin ownership

`bins.created_by_id` records the owner, and the API should allow an update only
when `role_id = 'admin'` or `created_by_id = <requester>`. That matches what the
Flutter app does today in `BinsRepository.canEdit`.

**This is worth confirming with your team lead.** Right now an ambassador manages
only bins they created. The alternative — ambassadors managing every bin in an
assigned `ambassador_area` — is more realistic for a recycling scheme but needs
a geographic containment check in the API. The `users.ambassador_area` column
already exists to support it.

## Three gaps this schema closes

These were live problems in the Firebase version:

1. **Redemption queue.** Redemptions were written under the user and never read.
   `redemptions.status` gives the admin console something to list.
2. **Contact messages.** The form wrote into a collection nothing read back.
   `contact_messages` has `status` plus `reply` / `replied_at`.
3. **Collection log.** Marking a bin collected only reset its level. `collections`
   records who, how much, whether it was weighed or estimated, and when.

## Sensors (left open on purpose)

You have not decided how hardware will report, so nothing here forces the issue.
What is already in place:

- `bins.sensor_id` — one sensor per bin, `UNIQUE`.
- `bin_status_events.source` — `sensor` or `manual`, so you can always tell a
  device reading from a human guess. The Flutter UI already greys out the manual
  slider for sensor-backed bins; this column is where that comes from.
- `bins.last_reported_at` — supports "stale sensor" detection.

Whatever transport you choose (HTTPS polling, MQTT bridge, a collector phone),
it writes to the same two columns.

## Before the server goes live

- Create a **non-superuser** role for the app. `postgres` should not be what the
  API connects as.
- Enable TLS (`sslmode=require`) between app and database.
- Back up `pg_dump` on a schedule and test a restore.
- The `users` table holds phone numbers, names and locations. It needs the same
  handling as any other personal data — restrict backups and do not log query
  parameters.
