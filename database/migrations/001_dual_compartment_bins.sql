-- ============================================================
-- 001 - Dual-compartment bins
--
-- The Flutter app has shown two fill levels per bin (accepted and rejected
-- compartments) and a "what does this bin collect" label since the admin
-- redesign landed, but the schema only ever had one. These columns close that
-- gap so the API can stop discarding the data the UI asks for.
--
-- New databases get these from schema.sql and do not need this file. Apply it
-- to a database that was created from the previous schema:
--
--   psql -d ecosystem -v ON_ERROR_STOP=1 -f database/migrations/001_dual_compartment_bins.sql
-- ============================================================

begin;

-- Guarded so re-running is a no-op rather than an error.
alter table bins
    add column if not exists rejected_fill_percent numeric(5,2)
        not null default 0
        check (rejected_fill_percent >= 0 and rejected_fill_percent <= 100);

alter table bins
    add column if not exists collects text not null default 'Plastic';

commit;
