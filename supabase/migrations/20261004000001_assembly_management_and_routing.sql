-- ============================================================================
-- Migration: 20261004000001_assembly_management_and_routing.sql
-- Description: Simplified District Registration (no assemblies), Post-Approval
--              Assembly Management (Add/Rename/Hide with RLS guards), and
--              Pastor District Routing Status.
-- ============================================================================

-- 1. ADD IS_ACTIVE TO ASSEMBLIES
ALTER TABLE assemblies ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Unique index for assembly name inside the same district (case-insensitive & extra-spaces normalized)
CREATE UNIQUE INDEX IF NOT EXISTS idx_assemblies_district_name_normalized_unique
    ON assemblies (district_id, lower(regexp_replace(trim(name), '\s+', ' ', 'g')));

-- 2. UPDATED REGISTER_DISTRICT_BY_PASTOR (NO LONGER REQUIRES OR ACCEPTS ASSEMBLIES)
CREATE OR REPLACE FUNCTION register_district_by_pastor(
    p_name TEXT,
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

    -- Check duplicate name (case-insensitive & space-normalized)
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

    -- 2. Link pastor's profile to the district
    UPDATE profiles
    SET district_id = v_district_id,
        updated_at = now()
    WHERE id = v_pastor_id;

    -- 3. Notify Area Head
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

    -- 4. Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, payload)
    VALUES (
        v_pastor_id,
        'REGISTER_DISTRICT',
        'districts',
        v_district_id,
        jsonb_build_object('name', v_clean_name, 'start_date', COALESCE(p_start_date, CURRENT_DATE))
    );

    RETURN jsonb_build_object(
        'success', true,
        'district_id', v_district_id,
        'name', v_clean_name,
        'status', 'pending'
    );
END;
$$;

-- 3. UPDATED APPROVE_DISTRICT (SENDS ASSEMBLY ONBOARDING NOTIFICATION)
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

        -- Send approval & assembly onboarding notification to pastor
        INSERT INTO notifications (user_id, title, body, payload)
        VALUES (
            v_pastor_id,
            'District Approved!',
            'Your district was approved. Add your assemblies to get started.',
            jsonb_build_object('district_id', p_district_id, 'status', 'active')
        );
    END IF;

    -- Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'APPROVE_DISTRICT', 'districts', p_district_id);

    RETURN jsonb_build_object('success', true, 'status', 'active');
END;
$$;

-- 4. RPC: ADD ASSEMBLY BY PASTOR
CREATE OR REPLACE FUNCTION add_assembly_by_pastor(
    p_district_id UUID,
    p_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_clean_name TEXT;
    v_assembly_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT is_pastor() THEN
        RAISE EXCEPTION 'Only pastors can add assemblies.';
    END IF;

    IF NOT pastor_district_is_active(v_user_id) THEN
        RAISE EXCEPTION 'Your district must be active to add assemblies.';
    END IF;

    IF NOT is_active_pastor_for_district(p_district_id) OR get_auth_user_district_id() != p_district_id THEN
        RAISE EXCEPTION 'You can only add assemblies to your own active district.';
    END IF;

    v_clean_name := regexp_replace(trim(p_name), '\s+', ' ', 'g');
    IF length(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Please enter a valid assembly name.';
    END IF;

    -- Check duplicate name in same district
    IF EXISTS (
        SELECT 1 FROM assemblies
        WHERE district_id = p_district_id
          AND lower(regexp_replace(trim(name), '\s+', ' ', 'g')) = lower(v_clean_name)
    ) THEN
        RAISE EXCEPTION 'An assembly with this name already exists in your district.';
    END IF;

    INSERT INTO assemblies (district_id, name, is_active)
    VALUES (p_district_id, v_clean_name, true)
    RETURNING id INTO v_assembly_id;

    RETURN jsonb_build_object('success', true, 'id', v_assembly_id, 'name', v_clean_name);
END;
$$;

-- 5. RPC: UPDATE ASSEMBLY BY PASTOR (RENAME / HIDE)
CREATE OR REPLACE FUNCTION update_assembly_by_pastor(
    p_assembly_id UUID,
    p_name TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_district_id UUID;
    v_clean_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT is_pastor() THEN
        RAISE EXCEPTION 'Only pastors can update assemblies.';
    END IF;

    SELECT district_id INTO v_district_id FROM assemblies WHERE id = p_assembly_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assembly not found.';
    END IF;

    IF NOT pastor_district_is_active(v_user_id) THEN
        RAISE EXCEPTION 'Your district must be active to update assemblies.';
    END IF;

    IF NOT is_active_pastor_for_district(v_district_id) OR get_auth_user_district_id() != v_district_id THEN
        RAISE EXCEPTION 'You can only manage assemblies for your own active district.';
    END IF;

    IF p_name IS NOT NULL THEN
        v_clean_name := regexp_replace(trim(p_name), '\s+', ' ', 'g');
        IF length(v_clean_name) < 2 THEN
            RAISE EXCEPTION 'Please enter a valid assembly name.';
        END IF;

        IF EXISTS (
            SELECT 1 FROM assemblies
            WHERE district_id = v_district_id
              AND id != p_assembly_id
              AND lower(regexp_replace(trim(name), '\s+', ' ', 'g')) = lower(v_clean_name)
        ) THEN
            RAISE EXCEPTION 'An assembly with this name already exists in your district.';
        END IF;

        UPDATE assemblies SET name = v_clean_name WHERE id = p_assembly_id;
    END IF;

    IF p_is_active IS NOT NULL THEN
        UPDATE assemblies SET is_active = p_is_active WHERE id = p_assembly_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'id', p_assembly_id);
END;
$$;

-- 6. STRICT RLS POLICIES ON ASSEMBLIES
DROP POLICY IF EXISTS "Authenticated users can read assemblies" ON assemblies;
DROP POLICY IF EXISTS "Pastors can insert assemblies for their registered district" ON assemblies;
DROP POLICY IF EXISTS "Active pastors can insert assemblies for their active district" ON assemblies;
DROP POLICY IF EXISTS "Active pastors can update assemblies for their active district" ON assemblies;
DROP POLICY IF EXISTS "No deletion of assemblies" ON assemblies;

CREATE POLICY "Authenticated users can read assemblies"
    ON assemblies FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Active pastors can insert assemblies for their active district"
    ON assemblies FOR INSERT
    TO authenticated
    WITH CHECK (
        is_pastor() AND
        pastor_district_is_active(auth.uid()) AND
        is_active_pastor_for_district(assemblies.district_id) AND
        get_auth_user_district_id() = assemblies.district_id
    );

CREATE POLICY "Active pastors can update assemblies for their active district"
    ON assemblies FOR UPDATE
    TO authenticated
    USING (
        is_pastor() AND
        pastor_district_is_active(auth.uid()) AND
        is_active_pastor_for_district(assemblies.district_id) AND
        get_auth_user_district_id() = assemblies.district_id
    )
    WITH CHECK (
        is_pastor() AND
        pastor_district_is_active(auth.uid()) AND
        is_active_pastor_for_district(assemblies.district_id) AND
        get_auth_user_district_id() = assemblies.district_id
    );

CREATE POLICY "No direct deletion of assemblies"
    ON assemblies FOR DELETE
    TO authenticated
    USING (false);

-- 7. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION register_district_by_pastor(TEXT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_district(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION add_assembly_by_pastor(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_assembly_by_pastor(UUID, TEXT, BOOLEAN) TO authenticated;
