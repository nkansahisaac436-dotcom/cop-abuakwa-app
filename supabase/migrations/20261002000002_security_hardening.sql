-- ============================================================================
-- Migration: 20261002000002_security_hardening.sql
-- Description: Complete Security Audit Fixes & Hardening for Abuakwa Area Connect
-- ============================================================================

-- 1. ADD START_DATE COLUMN TO DISTRICTS IF MISSING
ALTER TABLE districts ADD COLUMN IF NOT EXISTS start_date DATE;

-- 2. ENABLE ROW LEVEL SECURITY ON ALL TABLES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE assemblies ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministries ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE supervision_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE pastor_tenures ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- 3. HARDENED SECURITY HELPER FUNCTIONS WITH EXPLICIT SEARCH_PATH
CREATE OR REPLACE FUNCTION get_auth_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION get_auth_user_district_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION is_area_head()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT (get_auth_user_role() = 'area_head');
$$;

CREATE OR REPLACE FUNCTION is_pastor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT (get_auth_user_role() = 'pastor');
$$;

CREATE OR REPLACE FUNCTION is_active_pastor_for_district(target_district_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM pastor_tenures
    WHERE pastor_id = auth.uid()
      AND district_id = target_district_id
      AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION is_ministry_leader_for(target_ministry_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM ministry_leaders
    WHERE user_id = auth.uid()
      AND ministry_id = target_ministry_id
  );
$$;

CREATE OR REPLACE FUNCTION pastor_district_is_active(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM profiles p
        JOIN districts d ON p.district_id = d.id
        WHERE p.id = p_user_id
          AND p.status = 'active'
          AND d.status = 'active'
    );
$$;

-- 4. PREVENT SELF-PROMOTION TRIGGER ON PROFILES
CREATE OR REPLACE FUNCTION enforce_profile_update_security()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- If executed by Area Head or internal trigger, allow updates
    IF is_area_head() THEN
        RETURN NEW;
    END IF;

    -- Non-admin users cannot alter role, status, or district_id directly
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        RAISE EXCEPTION 'You are not permitted to change your role.';
    END IF;

    IF OLD.status IS DISTINCT FROM NEW.status THEN
        RAISE EXCEPTION 'You are not permitted to change your account status.';
    END IF;

    IF OLD.district_id IS DISTINCT FROM NEW.district_id AND NOT is_pastor() THEN
        RAISE EXCEPTION 'You cannot change your assigned district directly.';
    END IF;

    IF OLD.id IS DISTINCT FROM NEW.id THEN
        RAISE EXCEPTION 'Cannot modify profile id.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profile_update_security ON profiles;
CREATE TRIGGER trg_enforce_profile_update_security
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION enforce_profile_update_security();

-- 5. RATE LIMITING TABLE FOR INVITE ATTEMPTS
CREATE TABLE IF NOT EXISTS invite_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ip_address TEXT,
    user_id UUID,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    success BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE invite_attempts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION check_invite_rate_limit(p_user_id UUID DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_recent_failed_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_recent_failed_count
    FROM invite_attempts
    WHERE (user_id = p_user_id OR p_user_id IS NULL)
      AND success = false
      AND attempted_at > now() - INTERVAL '15 minutes';

    IF v_recent_failed_count >= 5 THEN
        RAISE EXCEPTION 'Too many tries. Please wait 15 minutes and try again.';
    END IF;
END;
$$;

-- 6. HARDENED STORED PROCEDURES (SECURITY DEFINER + VALIDATION)

-- Register District by Pastor
CREATE OR REPLACE FUNCTION register_district_by_pastor(
    p_name TEXT,
    p_assemblies TEXT[],
    p_start_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_name TEXT;
    v_district_id UUID;
    v_assembly_name TEXT;
    v_pastor_id UUID;
    v_area_head_id UUID;
BEGIN
    v_pastor_id := auth.uid();
    IF v_pastor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT is_pastor() THEN
        RAISE EXCEPTION 'Only pastors can register a district.';
    END IF;

    v_clean_name := regexp_replace(trim(p_name), '\s+', ' ', 'g');
    IF length(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Please enter a valid district name.';
    END IF;

    -- Check duplicate name (case-insensitive & extra-space normalized)
    IF EXISTS (
        SELECT 1 FROM districts
        WHERE lower(regexp_replace(trim(name), '\s+', ' ', 'g')) = lower(v_clean_name)
    ) THEN
        RAISE EXCEPTION 'This district is already registered. Contact the Area Head office.';
    END IF;

    -- 1. Create pending district
    INSERT INTO districts (
        name,
        status,
        registered_by,
        submitted_at,
        start_date
    ) VALUES (
        v_clean_name,
        'pending',
        v_pastor_id,
        now(),
        COALESCE(p_start_date, CURRENT_DATE)
    ) RETURNING id INTO v_district_id;

    -- 2. Insert assemblies
    IF p_assemblies IS NOT NULL AND array_length(p_assemblies, 1) > 0 THEN
        FOREACH v_assembly_name IN ARRAY p_assemblies
        LOOP
            IF length(trim(v_assembly_name)) > 0 THEN
                INSERT INTO assemblies (district_id, name)
                VALUES (v_district_id, trim(v_assembly_name))
                ON CONFLICT (district_id, name) DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    -- 3. Link pastor's profile to district
    UPDATE profiles
    SET district_id = v_district_id,
        updated_at = now()
    WHERE id = v_pastor_id;

    -- 4. Notify Area Head
    SELECT id INTO v_area_head_id FROM profiles WHERE role = 'area_head' LIMIT 1;
    IF v_area_head_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, title, body, payload)
        VALUES (
            v_area_head_id,
            'New District Registration',
            format('A new district "%s" was submitted for your approval.', v_clean_name),
            jsonb_build_object('district_id', v_district_id, 'pastor_id', v_pastor_id)
        );
    END IF;

    -- 5. Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, payload)
    VALUES (
        v_pastor_id,
        'REGISTER_DISTRICT',
        'districts',
        v_district_id,
        jsonb_build_object('name', v_clean_name, 'assemblies_count', coalesce(array_length(p_assemblies, 1), 0))
    );

    RETURN jsonb_build_object(
        'success', true,
        'district_id', v_district_id,
        'name', v_clean_name,
        'status', 'pending'
    );
END;
$$;

-- Approve District
CREATE OR REPLACE FUNCTION approve_district(
    p_district_id UUID,
    p_decision_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_district RECORD;
    v_pastor_id UUID;
    v_start_date DATE;
BEGIN
    v_admin_id := auth.uid();
    IF NOT is_area_head() THEN
        RAISE EXCEPTION 'Only the Area Head can approve districts.';
    END IF;

    SELECT * INTO v_district FROM districts WHERE id = p_district_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'District not found.';
    END IF;

    -- Update district status to active
    UPDATE districts SET
        status = 'active',
        decided_by = v_admin_id,
        decided_at = now(),
        decision_note = p_decision_note,
        activated_by = v_admin_id,
        activated_at = now(),
        updated_at = now()
    WHERE id = p_district_id;

    -- Initiate pastor tenure if registered by a pastor
    v_pastor_id := v_district.registered_by;
    v_start_date := COALESCE(v_district.start_date, CURRENT_DATE);

    IF v_pastor_id IS NOT NULL THEN
        INSERT INTO pastor_tenures (
            pastor_id,
            district_id,
            start_date,
            status
        ) VALUES (
            v_pastor_id,
            p_district_id,
            v_start_date,
            'active'
        ) ON CONFLICT DO NOTHING;

        -- Ensure pastor profile points to active district
        UPDATE profiles
        SET district_id = p_district_id,
            status = 'active',
            updated_at = now()
        WHERE id = v_pastor_id;

        -- Notify pastor
        INSERT INTO notifications (user_id, title, body, payload)
        VALUES (
            v_pastor_id,
            'District Approved!',
            format('Your registration for "%s" has been approved by the Area Head.', v_district.name),
            jsonb_build_object('district_id', p_district_id, 'status', 'active')
        );
    END IF;

    -- Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'APPROVE_DISTRICT', 'districts', p_district_id);

    RETURN jsonb_build_object('success', true, 'status', 'active');
END;
$$;

-- Reject District
CREATE OR REPLACE FUNCTION reject_district(
    p_district_id UUID,
    p_decision_note TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_district RECORD;
    v_pastor_id UUID;
BEGIN
    v_admin_id := auth.uid();
    IF NOT is_area_head() THEN
        RAISE EXCEPTION 'Only the Area Head can reject districts.';
    END IF;

    IF p_decision_note IS NULL OR length(trim(p_decision_note)) = 0 THEN
        RAISE EXCEPTION 'A note explaining the rejection is required.';
    END IF;

    SELECT * INTO v_district FROM districts WHERE id = p_district_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'District not found.';
    END IF;

    -- Update district status to rejected
    UPDATE districts SET
        status = 'rejected',
        decided_by = v_admin_id,
        decided_at = now(),
        decision_note = trim(p_decision_note),
        updated_at = now()
    WHERE id = p_district_id;

    v_pastor_id := v_district.registered_by;
    IF v_pastor_id IS NOT NULL THEN
        -- Notify pastor
        INSERT INTO notifications (user_id, title, body, payload)
        VALUES (
            v_pastor_id,
            'District Registration Update',
            format('Your registration for "%s" needs attention: %s', v_district.name, trim(p_decision_note)),
            jsonb_build_object('district_id', p_district_id, 'status', 'rejected', 'note', trim(p_decision_note))
        );
    END IF;

    -- Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, payload)
    VALUES (v_admin_id, 'REJECT_DISTRICT', 'districts', p_district_id, jsonb_build_object('note', trim(p_decision_note)));

    RETURN jsonb_build_object('success', true, 'status', 'rejected');
END;
$$;

-- Verify Invite Code
CREATE OR REPLACE FUNCTION verify_invite_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_code TEXT;
    v_invite RECORD;
    v_district_name TEXT;
    v_ministry_name TEXT;
BEGIN
    PERFORM check_invite_rate_limit(auth.uid());

    v_clean_code := UPPER(TRIM(p_code));

    SELECT * INTO v_invite
    FROM invites
    WHERE (code_display = v_clean_code OR code_hash = v_clean_code)
      AND status = 'pending'
      AND expires_at > now();

    IF NOT FOUND THEN
        INSERT INTO invite_attempts (user_id, success) VALUES (auth.uid(), false);
        RAISE EXCEPTION 'This code is not valid. Ask your Area Head for a new one.';
    END IF;

    INSERT INTO invite_attempts (user_id, success) VALUES (auth.uid(), true);

    IF v_invite.district_id IS NOT NULL THEN
        SELECT name INTO v_district_name FROM districts WHERE id = v_invite.district_id;
    END IF;

    IF v_invite.ministry_id IS NOT NULL THEN
        SELECT name INTO v_ministry_name FROM ministries WHERE id = v_invite.ministry_id;
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'code', v_invite.code_display,
        'role', v_invite.role,
        'target_name', v_invite.target_name,
        'district_id', v_invite.district_id,
        'district_name', v_district_name,
        'ministry_id', v_invite.ministry_id,
        'ministry_name', v_ministry_name,
        'expires_at', v_invite.expires_at
    );
END;
$$;

-- Redeem Invite
CREATE OR REPLACE FUNCTION redeem_invite(
    p_code TEXT,
    p_user_id UUID,
    p_email TEXT,
    p_full_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_code TEXT;
    v_invite RECORD;
    v_tenure_id UUID;
BEGIN
    PERFORM check_invite_rate_limit(p_user_id);

    v_clean_code := UPPER(TRIM(p_code));

    -- Lock the invite row for update
    SELECT * INTO v_invite
    FROM invites
    WHERE (code_display = v_clean_code OR code_hash = v_clean_code)
      AND status = 'pending'
      AND expires_at > now()
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO invite_attempts (user_id, success) VALUES (p_user_id, false);
        RAISE EXCEPTION 'This code is not valid. Ask your Area Head for a new one.';
    END IF;

    INSERT INTO invite_attempts (user_id, success) VALUES (p_user_id, true);

    -- 1. Create or update profile
    INSERT INTO profiles (
        id,
        full_name,
        email,
        role,
        status,
        district_id,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        COALESCE(NULLIF(p_full_name, ''), v_invite.target_name),
        LOWER(TRIM(p_email)),
        v_invite.role,
        'active',
        v_invite.district_id,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        status = 'active',
        district_id = EXCLUDED.district_id,
        full_name = EXCLUDED.full_name,
        updated_at = now();

    -- 2. If Pastor with pre-assigned district: initiate active tenure
    IF v_invite.role = 'pastor' AND v_invite.district_id IS NOT NULL THEN
        INSERT INTO pastor_tenures (
            pastor_id,
            district_id,
            start_date,
            status
        ) VALUES (
            p_user_id,
            v_invite.district_id,
            CURRENT_DATE,
            'active'
        ) ON CONFLICT DO NOTHING;
    END IF;

    -- 3. If Ministry Leader: link ministry leadership
    IF v_invite.role = 'ministry_leader' AND v_invite.ministry_id IS NOT NULL THEN
        INSERT INTO ministry_leaders (user_id, ministry_id)
        VALUES (p_user_id, v_invite.ministry_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4. Mark invite as redeemed
    UPDATE invites SET
        status = 'redeemed',
        redeemed_by = p_user_id,
        redeemed_at = now()
    WHERE id = v_invite.id;

    -- 5. Audit log
    INSERT INTO audit_log (actor_id, action, entity, entity_id)
    VALUES (p_user_id, 'redeem_invite', 'invites', v_invite.id);

    RETURN jsonb_build_object(
        'success', true,
        'role', v_invite.role,
        'district_id', v_invite.district_id,
        'ministry_id', v_invite.ministry_id
    );
END;
$$;

-- Delete Own Account (GDPR / Privacy Compliance)
CREATE OR REPLACE FUNCTION delete_own_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF is_area_head() THEN
        RAISE EXCEPTION 'The Area Head account cannot be deleted via self-service.';
    END IF;

    -- Anonymize/delete user profile
    DELETE FROM profiles WHERE id = v_user_id;
    
    RETURN jsonb_build_object('success', true);
END;
$$;

-- 7. AUDIT LOG IMMUTABILITY POLICIES
DROP POLICY IF EXISTS "Audit log is viewable by Area Head only" ON audit_log;
DROP POLICY IF EXISTS "Authenticated users can create audit log entries" ON audit_log;

CREATE POLICY "Audit log is viewable by Area Head only"
    ON audit_log FOR SELECT
    TO authenticated
    USING (is_area_head());

CREATE POLICY "Authenticated users can create audit log entries"
    ON audit_log FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = actor_id);

-- No UPDATE or DELETE policy on audit_log exists -> permanently immutable via API.

-- 8. GRANT EXECUTE ON RPC FUNCTIONS TO AUTHENTICATED
GRANT EXECUTE ON FUNCTION get_auth_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION get_auth_user_district_id TO authenticated;
GRANT EXECUTE ON FUNCTION is_area_head TO authenticated;
GRANT EXECUTE ON FUNCTION is_pastor TO authenticated;
GRANT EXECUTE ON FUNCTION is_active_pastor_for_district TO authenticated;
GRANT EXECUTE ON FUNCTION is_ministry_leader_for TO authenticated;
GRANT EXECUTE ON FUNCTION pastor_district_is_active TO authenticated;
GRANT EXECUTE ON FUNCTION register_district_by_pastor TO authenticated;
GRANT EXECUTE ON FUNCTION approve_district TO authenticated;
GRANT EXECUTE ON FUNCTION reject_district TO authenticated;
GRANT EXECUTE ON FUNCTION verify_invite_code TO authenticated, anon;
GRANT EXECUTE ON FUNCTION redeem_invite TO authenticated, anon;
GRANT EXECUTE ON FUNCTION delete_own_account TO authenticated;
