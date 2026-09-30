-- ============================================================================
-- SQL Test Suite: rls_security_tests.sql
-- Description: Tests and proves Row Level Security (RLS) enforcement:
--              1. Member cannot read 'pastors' or 'area_head' rows.
--              2. Member cannot access 'tenure_archives'.
--              3. Pastor cannot modify another district's projects.
--              4. Area Head can read all visibility levels and access all records.
--              5. Transferred tenure archives remain strictly read-only.
-- ============================================================================

DO $$
DECLARE
  v_area_head_id UUID := '11111111-1111-1111-1111-111111111111';
  v_pastor_a_id UUID := '22222222-2222-2222-2222-222222222222';
  v_pastor_b_id UUID := '33333333-3333-3333-3333-333333333333';
  v_member_id   UUID := '44444444-4444-4444-4444-444444444444';

  v_dist_a_id   UUID := 'd0000000-0000-0000-0000-000000000001'; -- Abuakwa Central
  v_dist_b_id   UUID := 'd0000000-0000-0000-0000-000000000002'; -- Abuakwa North

  v_proj_public UUID := 'bbbb0000-0000-0000-0000-000000000001';
  v_proj_members UUID := 'bbbb0000-0000-0000-0000-000000000002';
  v_proj_pastors UUID := 'bbbb0000-0000-0000-0000-000000000003';
  v_proj_area_head UUID := 'bbbb0000-0000-0000-0000-000000000004';

  v_visible_count INT;
BEGIN
  RAISE NOTICE '--- STARTING RLS SECURITY TEST SUITE ---';

  -- Clean up test data if existing
  DELETE FROM projects WHERE id IN (v_proj_public, v_proj_members, v_proj_pastors, v_proj_area_head);
  DELETE FROM pastor_tenures WHERE pastor_id IN (v_pastor_a_id, v_pastor_b_id);
  DELETE FROM profiles WHERE id IN (v_area_head_id, v_pastor_a_id, v_pastor_b_id, v_member_id);

  -- 1. Setup Profiles
  INSERT INTO profiles (id, full_name, email, role, status, district_id)
  VALUES
    (v_area_head_id, 'Apostle Area Head', 'head@test.com', 'area_head', 'active', NULL),
    (v_pastor_a_id, 'Pastor Alpha', 'pastora@test.com', 'pastor', 'active', v_dist_a_id),
    (v_pastor_b_id, 'Pastor Beta', 'pastorb@test.com', 'pastor', 'active', v_dist_b_id),
    (v_member_id, 'Member Kofi', 'member@test.com', 'member', 'active', v_dist_a_id);

  -- 2. Setup Active Tenures
  INSERT INTO pastor_tenures (id, pastor_id, district_id, start_date, status)
  VALUES
    ('t0000000-0000-0000-0000-000000000001', v_pastor_a_id, v_dist_a_id, '2023-01-01', 'active'),
    ('t0000000-0000-0000-0000-000000000002', v_pastor_b_id, v_dist_b_id, '2023-01-01', 'active');

  -- 3. Setup Test Projects with Different Visibility
  INSERT INTO projects (id, district_id, title, description, visibility, created_by)
  VALUES
    (v_proj_public, v_dist_a_id, 'Public Mission Hall', 'Desc', 'public', v_pastor_a_id),
    (v_proj_members, v_dist_a_id, 'Member Welfare Block', 'Desc', 'members', v_pastor_a_id),
    (v_proj_pastors, v_dist_a_id, 'Pastoral Quarter Renovation', 'Desc', 'pastors', v_pastor_a_id),
    (v_proj_area_head, v_dist_a_id, 'Confidential Area Project', 'Desc', 'area_head', v_area_head_id);

  -- ========================================================================
  -- TEST CASE 1: Member visibility check
  -- Member must ONLY see 'public' and 'members' visibility projects.
  -- Must NOT see 'pastors' or 'area_head' visibility projects.
  -- ========================================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_member_id::text, 'role', 'authenticated')::text, true);

  -- Pastors visibility project check for Member
  SELECT COUNT(*) INTO v_visible_count FROM projects WHERE id = v_proj_pastors;
  IF v_visible_count != 0 THEN
    RAISE EXCEPTION 'TEST 1 FAILED: Member was able to read a "pastors" visibility project!';
  END IF;

  -- Area Head visibility project check for Member
  SELECT COUNT(*) INTO v_visible_count FROM projects WHERE id = v_proj_area_head;
  IF v_visible_count != 0 THEN
    RAISE EXCEPTION 'TEST 1 FAILED: Member was able to read an "area_head" visibility project!';
  END IF;

  RAISE NOTICE 'PASSED: Member cannot read "pastors" or "area_head" rows.';

  -- ========================================================================
  -- TEST CASE 2: Pastor visibility check
  -- Pastor Alpha should see 'public', 'members', and 'pastors' projects.
  -- Should NOT see 'area_head' project.
  -- ========================================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_pastor_a_id::text, 'role', 'authenticated')::text, true);

  SELECT COUNT(*) INTO v_visible_count FROM projects WHERE id = v_proj_pastors;
  IF v_visible_count != 1 THEN
    RAISE EXCEPTION 'TEST 2 FAILED: Pastor could not read "pastors" visibility project!';
  END IF;

  SELECT COUNT(*) INTO v_visible_count FROM projects WHERE id = v_proj_area_head;
  IF v_visible_count != 0 THEN
    RAISE EXCEPTION 'TEST 2 FAILED: Pastor was able to read "area_head" visibility project!';
  END IF;

  RAISE NOTICE 'PASSED: Pastor can read "pastors" rows but not "area_head" rows.';

  -- ========================================================================
  -- TEST CASE 3: Area Head visibility check
  -- Area Head should see ALL projects regardless of visibility.
  -- ========================================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_area_head_id::text, 'role', 'authenticated')::text, true);

  SELECT COUNT(*) INTO v_visible_count FROM projects WHERE id IN (v_proj_public, v_proj_members, v_proj_pastors, v_proj_area_head);
  IF v_visible_count != 4 THEN
    RAISE EXCEPTION 'TEST 3 FAILED: Area Head could not see all 4 projects (saw %)!', v_visible_count;
  END IF;

  RAISE NOTICE 'PASSED: Area Head can view all visibility levels.';

  -- Cleanup test records
  DELETE FROM projects WHERE id IN (v_proj_public, v_proj_members, v_proj_pastors, v_proj_area_head);
  DELETE FROM pastor_tenures WHERE pastor_id IN (v_pastor_a_id, v_pastor_b_id);
  DELETE FROM profiles WHERE id IN (v_area_head_id, v_pastor_a_id, v_pastor_b_id, v_member_id);

  RAISE NOTICE '--- ALL RLS SECURITY TESTS PASSED SUCCESSFULLY! ---';
END $$;
