-- ============================================================
-- 002 - Reward catalogue fields and member-facing endpoints
--
-- The admin console has always let a staff member write a description and
-- pick 'standard' vs 'partner' when adding a reward, but the table only kept
-- the partner name. Both fields are now stored.
--
-- New databases get these from schema.sql. To bring an existing one up to
-- date:
--
--   psql -d ecosystem -v ON_ERROR_STOP=1 -f database/migrations/002_rewards_catalogue.sql
-- ============================================================

begin;

alter table rewards
    add column if not exists description text;

alter table rewards
    add column if not exists category text not null default 'standard';

-- Guarded separately so re-running against a database that already has the
-- column but not the constraint still converges.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'rewards_category_check'
  ) then
    alter table rewards
      add constraint rewards_category_check
      check (category in ('standard', 'partner'));
  end if;
end
$$;

commit;
