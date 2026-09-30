-- ============================================================================
-- Migration: 20260930000002_rls_policies.sql
-- Description: Row Level Security (RLS) policies and security helper functions
-- ============================================================================

-- Enable RLS on all relevant tables
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE assemblies ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministries ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE pastor_tenures ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenure_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTIONS FOR RLS (Runs with SECURITY DEFINER to bypass recursion)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_auth_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_auth_user_district_id()
RETURNS UUID AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_area_head()
RETURNS BOOLEAN AS $$
  SELECT (get_auth_user_role() = 'area_head');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_pastor()
RETURNS BOOLEAN AS $$
  SELECT (get_auth_user_role() = 'pastor');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_active_pastor_for_district(target_district_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM pastor_tenures
    WHERE pastor_id = auth.uid()
      AND district_id = target_district_id
      AND status = 'active'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_ministry_leader_for(target_ministry_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM ministry_leaders
    WHERE user_id = auth.uid()
      AND ministry_id = target_ministry_id
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================================
-- 1. DISTRICTS POLICIES
-- ============================================================================
-- Everyone can read districts (needed for sign-up dropdown and public feed)
CREATE POLICY "Districts are viewable by everyone"
ON districts FOR SELECT
USING (true);

-- Only Area Head can insert, update, or delete districts
CREATE POLICY "Districts are editable only by Area Head"
ON districts FOR ALL
USING (is_area_head())
WITH CHECK (is_area_head());

-- ============================================================================
-- 2. ASSEMBLIES POLICIES
-- ============================================================================
CREATE POLICY "Assemblies are viewable by everyone"
ON assemblies FOR SELECT
USING (true);

CREATE POLICY "Assemblies are manageable by Area Head and active Pastor"
ON assemblies FOR ALL
USING (
  is_area_head() OR is_active_pastor_for_district(district_id)
)
WITH CHECK (
  is_area_head() OR is_active_pastor_for_district(district_id)
);

-- ============================================================================
-- 3. PROFILES POLICIES
-- ============================================================================
-- Users can view their own profile, or Area Head and Pastors can view profiles
CREATE POLICY "Profiles viewable by authenticated users"
ON profiles FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can insert their own profile during signup"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile details"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id OR is_area_head())
WITH CHECK (
  (auth.uid() = id AND role = (SELECT role FROM profiles WHERE id = auth.uid()))
  OR is_area_head()
);

-- ============================================================================
-- 4. MINISTRIES & LEADERS & FOLLOWS POLICIES
-- ============================================================================
CREATE POLICY "Ministries are viewable by everyone"
ON ministries FOR SELECT
USING (true);

CREATE POLICY "Ministries manageable only by Area Head"
ON ministries FOR ALL
USING (is_area_head())
WITH CHECK (is_area_head());

CREATE POLICY "Ministry leaders viewable by authenticated"
ON ministry_leaders FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Ministry leaders assigned by Area Head"
ON ministry_leaders FOR ALL
USING (is_area_head())
WITH CHECK (is_area_head());

CREATE POLICY "Users can view and manage their own ministry follows"
ON ministry_follows FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 5. PASTOR TENURES POLICIES
-- ============================================================================
CREATE POLICY "Pastor tenures viewable by authenticated users"
ON pastor_tenures FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Pastor tenures manageable only by Area Head"
ON pastor_tenures FOR ALL
USING (is_area_head())
WITH CHECK (is_area_head());

-- ============================================================================
-- 6. PROJECTS POLICIES
-- ============================================================================
-- Visibility rules:
-- - public: anyone with the app
-- - members: any logged-in user
-- - pastors: pastors and area_head only
-- - area_head: area_head only
CREATE POLICY "Projects select policy"
ON projects FOR SELECT
USING (
  visibility = 'public'
  OR (auth.role() = 'authenticated' AND visibility = 'members')
  OR ((get_auth_user_role() IN ('pastor', 'area_head')) AND visibility = 'pastors')
  OR is_area_head()
);

-- Pastor can create projects only for his own active district
CREATE POLICY "Projects insert policy"
ON projects FOR INSERT
TO authenticated
WITH CHECK (
  is_area_head()
  OR (is_pastor() AND is_active_pastor_for_district(district_id))
);

-- Pastor can edit projects only for his own active district and during active tenure
CREATE POLICY "Projects update policy"
ON projects FOR UPDATE
TO authenticated
USING (
  is_area_head()
  OR (is_pastor() AND is_active_pastor_for_district(district_id))
)
WITH CHECK (
  is_area_head()
  OR (is_pastor() AND is_active_pastor_for_district(district_id))
);

CREATE POLICY "Projects delete policy"
ON projects FOR DELETE
TO authenticated
USING (
  is_area_head()
  OR (is_pastor() AND is_active_pastor_for_district(district_id))
);

-- ============================================================================
-- 7. PROJECT UPDATES POLICIES
-- ============================================================================
CREATE POLICY "Project updates select policy"
ON project_updates FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_updates.project_id
      AND (
        p.visibility = 'public'
        OR (auth.role() = 'authenticated' AND p.visibility = 'members')
        OR ((get_auth_user_role() IN ('pastor', 'area_head')) AND p.visibility = 'pastors')
        OR is_area_head()
      )
  )
);

CREATE POLICY "Project updates insert policy"
ON project_updates FOR INSERT
TO authenticated
WITH CHECK (
  is_area_head()
  OR EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_updates.project_id
      AND is_active_pastor_for_district(p.district_id)
  )
);

-- ============================================================================
-- 8. VISITS POLICIES (Supervision Visit Log)
-- ============================================================================
CREATE POLICY "Visits select policy"
ON visits FOR SELECT
TO authenticated
USING (
  is_area_head()
  OR (visibility = 'pastors' AND get_auth_user_role() IN ('pastor', 'area_head'))
  OR (visibility = 'members')
  OR (visibility = 'public')
);

CREATE POLICY "Visits manageable only by Area Head"
ON visits FOR ALL
TO authenticated
USING (is_area_head())
WITH CHECK (is_area_head());

-- ============================================================================
-- 9. POSTS POLICIES (Announcements, Thoughts, News)
-- ============================================================================
CREATE POLICY "Posts select policy"
ON posts FOR SELECT
USING (
  visibility = 'public'
  OR (auth.role() = 'authenticated' AND visibility = 'members')
  OR ((get_auth_user_role() IN ('pastor', 'area_head')) AND visibility = 'pastors')
  OR is_area_head()
);

CREATE POLICY "Posts insert policy"
ON posts FOR INSERT
TO authenticated
WITH CHECK (
  -- Area Head can post anything
  is_area_head()
  -- Pastor can post thoughts or district news for their active district
  OR (
    is_pastor()
    AND (district_id IS NULL OR is_active_pastor_for_district(district_id))
  )
  -- Ministry leader can post only to their assigned ministry
  OR (
    get_auth_user_role() = 'ministry_leader'
    AND ministry_id IS NOT NULL
    AND is_ministry_leader_for(ministry_id)
  )
);

CREATE POLICY "Posts update policy"
ON posts FOR UPDATE
TO authenticated
USING (
  is_area_head()
  OR (author_id = auth.uid())
)
WITH CHECK (
  is_area_head()
  OR (author_id = auth.uid())
);

CREATE POLICY "Posts delete policy"
ON posts FOR DELETE
TO authenticated
USING (
  is_area_head()
  OR (author_id = auth.uid())
);

-- ============================================================================
-- 10. MEETINGS POLICIES
-- ============================================================================
CREATE POLICY "Meetings select policy"
ON meetings FOR SELECT
TO authenticated
USING (
  is_area_head()
  OR (audience = 'pastor' AND get_auth_user_role() IN ('pastor', 'area_head'))
  OR (audience = 'member')
);

CREATE POLICY "Meetings insert policy"
ON meetings FOR INSERT
TO authenticated
WITH CHECK (
  is_area_head() OR is_pastor()
);

-- ============================================================================
-- 11. TRANSFER REQUESTS POLICIES
-- ============================================================================
CREATE POLICY "Transfer requests select policy"
ON transfer_requests FOR SELECT
TO authenticated
USING (
  is_area_head()
  OR (pastor_id = auth.uid())
);

CREATE POLICY "Pastors can create transfer requests for themselves"
ON transfer_requests FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = pastor_id
  AND is_pastor()
);

CREATE POLICY "Only Area Head can update/decide transfer requests"
ON transfer_requests FOR UPDATE
TO authenticated
USING (is_area_head())
WITH CHECK (is_area_head());

-- ============================================================================
-- 12. TENURE ARCHIVES POLICIES (Read-only for Area Head and Pastors, NEVER Members)
-- ============================================================================
CREATE POLICY "Tenure archives viewable only by Area Head and Pastors"
ON tenure_archives FOR SELECT
TO authenticated
USING (
  get_auth_user_role() IN ('area_head', 'pastor')
);

-- Archives are immutable (read-only for all users via standard UI)
CREATE POLICY "Tenure archives insert by system/Area Head only"
ON tenure_archives FOR INSERT
TO authenticated
WITH CHECK (is_area_head());

-- No UPDATE or DELETE allowed on tenure_archives to enforce permanent immutability

-- ============================================================================
-- 13. NOTIFICATIONS POLICIES
-- ============================================================================
CREATE POLICY "Users can read and update their own notifications"
ON notifications FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 14. DEVICE TOKENS POLICIES
-- ============================================================================
CREATE POLICY "Users manage their own device tokens"
ON device_tokens FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 15. AUDIT LOG POLICIES
-- ============================================================================
CREATE POLICY "Audit logs viewable only by Area Head"
ON audit_log FOR SELECT
TO authenticated
USING (is_area_head());
