-- ============================================================
-- Ecosystem - verification queries
--
-- After running schema.sql and seed.sql, run this file. Every query
-- should return rows. If one returns nothing, that part of the
-- schema is not wired up correctly.
-- ============================================================

\echo '--- 0. encoding must be UTF8 or emoji in avatar_icon will break ---'
SELECT current_database() AS db, pg_encoding_to_char(encoding) AS encoding
FROM pg_database WHERE datname = current_database();

\echo '--- 1. roles (expect 3 rows) ---'
SELECT id, label, can_manage_bins, can_approve, can_administer FROM roles ORDER BY id;

\echo '--- 2. users (expect 6) ---'
SELECT name, role_id, ambassador_state, points, bottles, weight_kg
FROM users ORDER BY name;

\echo '--- 3. TRIGGER CHECK: totals were computed from deposits ---'
\echo '    Expected: Kweku 100pts/20 bottles, Abena 130pts/26, Yaw 75pts/15 ---'
SELECT nickname, points, bottles, weight_kg
FROM users WHERE role_id = 'user' ORDER BY nickname;

\echo '--- 4. leaderboard view ---'
\echo '    Admins are excluded; ambassadors are included, since they recycle too.'
\echo '    Expect 5 rows: 3 members plus the 2 ambassadors tied at rank 4.'
SELECT rank, nickname, points, bottles, weight_kg FROM leaderboard ORDER BY rank;

\echo '--- 5. bins (expect 6) ---'
SELECT code, name, bin_state, status_source, fill_percent, sensor_id, created_by_id
FROM bins ORDER BY code;

\echo '--- 6. bin_summary view (expect 1 row: 2 available, 1 filling, 2 full, 1 disabled) ---'
SELECT * FROM bin_summary;

\echo '--- 7. status history was backfilled (expect 6 rows) ---'
SELECT b.code, e.previous_state, e.new_state, e.source, e.reported_by_id
FROM bin_status_events e JOIN bins b ON b.id = e.bin_id
ORDER BY b.code;

\echo '--- 8. rfid_cards (expect 5) ---'
SELECT tag_normalised, tag_length, card_kind, state, assigned_user_id
FROM rfid_cards ORDER BY tag_normalised;

\echo '--- 9. admin_dashboard_summary (expect 1 populated row) ---'
SELECT * FROM admin_dashboard_summary;

\echo '--- 10. queues that Firebase had no reader for (expect 3/2/2) ---'
SELECT 'redemptions' AS queue, count(*) FROM redemptions
UNION ALL SELECT 'contact_messages', count(*) FROM contact_messages
UNION ALL SELECT 'notifications', count(*) FROM notifications;

\echo '--- 11. RFID dedupe: this MUST return 0 rows ---'
\echo '     tag_normalised is UNIQUE, so one card cannot be two records.'
SELECT tag_normalised, count(*) FROM rfid_cards
GROUP BY tag_normalised HAVING count(*) > 1;

\echo '--- 12. bins must have both coordinates or neither (expect 0 rows) ---'
SELECT code FROM bins WHERE (latitude IS NULL) <> (longitude IS NULL);

\echo '--- 13. audit log (expect 2) ---'
SELECT action, entity_type, entity_id, details FROM audit_log ORDER BY id;

\echo '--- 14. actor attribution works via app.actor_id ---'
\echo '     Sets a session variable, changes a bin, and checks the history row.'
BEGIN;
SET LOCAL app.actor_id = '00000000-0000-4000-8000-000000000002';
UPDATE bins SET fill_percent = 95 WHERE code = 'BIN-001';
SELECT b.code, e.previous_state, e.new_state, e.fill_percent,
       u.name AS reported_by
FROM bin_status_events e
JOIN bins b ON b.id = e.bin_id
LEFT JOIN users u ON u.id = e.reported_by_id
WHERE b.code = 'BIN-001' ORDER BY e.id DESC LIMIT 1;
ROLLBACK;

\echo '--- 15. one active card per user enforced (MUST return 0 rows) ---'
SELECT assigned_user_id, count(*) FROM rfid_cards
WHERE assigned_user_id IS NOT NULL AND state IN ('linked', 'lost')
GROUP BY assigned_user_id HAVING count(*) > 1;

\echo '--- done ---'
