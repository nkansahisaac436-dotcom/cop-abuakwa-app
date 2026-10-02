-- ============================================================================
-- One-off Cleanup Script: supabase/cleanup_demo_data.sql
-- Description: Safely purges all demo, sample, and test accounts, districts,
--              assemblies, projects, posts, meetings, and notifications while
--              strictly preserving the real Area Head account and 5 core ministries.
-- ============================================================================

-- INSTRUCTIONS FOR RUNNING:
-- 1. BACKUP / EXPORT:
--    Export a full database backup before running:
--    supabase db dump -f backup_before_cleanup_$(date +%Y%m%d%H%M%S).sql
--    or via Supabase Dashboard -> Database -> Backups.
-- 2. RUN: Execute this entire script inside SQL Editor or via CLI.
--    It is wrapped in a single transaction (BEGIN ... COMMIT) so any error
--    automatically rolls back without partial data corruption.

BEGIN;

-- 1. Delete all project updates, media, visits, and projects
DELETE FROM media;
DELETE FROM project_updates;
DELETE FROM visits;
DELETE FROM projects;

-- 1b. Delete demo files in storage buckets (keeps buckets & policies)
DELETE FROM storage.objects WHERE bucket_id IN ('post_media', 'avatars', 'archives');

-- 2. Delete all posts and meetings
DELETE FROM posts;
DELETE FROM meetings;

-- 3. Delete all transfer requests and tenure archives
DELETE FROM tenure_archives;
DELETE FROM transfer_requests;
DELETE FROM pastor_tenures;

-- 4. Delete all ministry follows and leader assignments
DELETE FROM ministry_follows;
DELETE FROM ministry_leaders;

-- 5. Delete all invites
DELETE FROM invites;

-- 6. Delete notifications and device tokens
DELETE FROM notifications;
DELETE FROM device_tokens;

-- 7. Delete audit logs for demo entities (keeping Area Head actions)
DELETE FROM audit_log WHERE actor_id NOT IN (
    SELECT id FROM profiles WHERE role = 'area_head'
);

-- 8. Delete all demo assemblies and districts
DELETE FROM assemblies;
DELETE FROM districts;

-- 9. Delete all non-Area Head user profiles
DELETE FROM profiles WHERE role != 'area_head';

-- 10. Delete corresponding non-Area Head auth users and identities
DELETE FROM auth.identities WHERE user_id NOT IN (
    SELECT id FROM profiles WHERE role = 'area_head'
);

DELETE FROM auth.users WHERE id NOT IN (
    SELECT id FROM profiles WHERE role = 'area_head'
);

COMMIT;

-- ============================================================================
-- VERIFICATION QUERY: Check row counts for every table after cleanup
-- ============================================================================
SELECT 'auth.users' AS table_name, count(*) AS remaining_rows FROM auth.users
UNION ALL
SELECT 'profiles', count(*) FROM profiles
UNION ALL
SELECT 'ministries', count(*) FROM ministries
UNION ALL
SELECT 'districts', count(*) FROM districts
UNION ALL
SELECT 'assemblies', count(*) FROM assemblies
UNION ALL
SELECT 'projects', count(*) FROM projects
UNION ALL
SELECT 'project_updates', count(*) FROM project_updates
UNION ALL
SELECT 'posts', count(*) FROM posts
UNION ALL
SELECT 'meetings', count(*) FROM meetings
UNION ALL
SELECT 'notifications', count(*) FROM notifications
UNION ALL
SELECT 'invites', count(*) FROM invites
UNION ALL
SELECT 'pastor_tenures', count(*) FROM pastor_tenures
UNION ALL
SELECT 'transfer_requests', count(*) FROM transfer_requests
UNION ALL
SELECT 'tenure_archives', count(*) FROM tenure_archives;
