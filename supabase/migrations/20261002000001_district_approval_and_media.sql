-- ============================================================================
-- Migration: 20261002000001_district_approval_and_media.sql
-- Description: Supports Pastor District Self-Registration, Approval Workflow,
--              Post Media, Storage Buckets, and RLS enforcement.
-- ============================================================================

-- 1. UPDATE DISTRICT_STATUS ENUM
DO $$
BEGIN
    ALTER TYPE district_status ADD VALUE IF NOT EXISTS 'pending';
    ALTER TYPE district_status ADD VALUE IF NOT EXISTS 'rejected';
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 2. ALTER DISTRICTS TABLE WITH REGISTRATION COLUMNS
ALTER TABLE districts
    ADD COLUMN IF NOT EXISTS registered_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS decided_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS decided_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS decision_note TEXT;

-- Set default status for new self-registered districts to 'pending'
ALTER TABLE districts ALTER COLUMN status SET DEFAULT 'pending';

-- Normalized unique index for district name (ignores case and extra spaces)
CREATE UNIQUE INDEX IF NOT EXISTS idx_districts_name_normalized_unique
    ON districts (lower(regexp_replace(trim(name), '\s+', ' ', 'g')));

-- 3. UPDATE MEDIA TABLE TO SUPPORT POSTS, PROJECT UPDATES, AND ORDERING
ALTER TABLE media
    ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS update_id UUID REFERENCES project_updates(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS storage_path TEXT,
    ADD COLUMN IF NOT EXISTS caption TEXT,
    ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_media_post_id ON media(post_id);
CREATE INDEX IF NOT EXISTS idx_media_update_id ON media(update_id);
CREATE INDEX IF NOT EXISTS idx_media_storage_path ON media(storage_path);

-- 4. CREATE STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('post_media', 'post_media', false, 15728640, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 5. STORAGE RLS POLICIES
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Avatars: Any authenticated user can view, owner can upload/update/delete
CREATE POLICY "Public authenticated avatars read"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update their own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete their own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Post Media: Authenticated users can upload and view
CREATE POLICY "Authenticated users can upload post media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'post_media');

CREATE POLICY "Authenticated users can read post media"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'post_media');

-- 6. DISTRICT REGISTRATION & APPROVAL RLS POLICIES
-- Pastors can register a new district
CREATE POLICY "Pastors can register a new district"
    ON districts FOR INSERT
    TO authenticated
    WITH CHECK (
        is_pastor() AND
        registered_by = auth.uid() AND
        status = 'pending'
    );

-- Pastors can update their pending or rejected district (for resubmission)
CREATE POLICY "Pastors can edit their own pending or rejected district"
    ON districts FOR UPDATE
    TO authenticated
    USING (
        is_pastor() AND
        registered_by = auth.uid() AND
        status IN ('pending', 'rejected')
    )
    WITH CHECK (
        is_pastor() AND
        registered_by = auth.uid() AND
        status IN ('pending', 'rejected')
    );

-- Pastors can insert assemblies for their registered district
CREATE POLICY "Pastors can insert assemblies for their registered district"
    ON assemblies FOR INSERT
    TO authenticated
    WITH CHECK (
        is_pastor() AND
        EXISTS (
            SELECT 1 FROM districts
            WHERE id = assemblies.district_id
              AND registered_by = auth.uid()
        )
    );

-- 7. RLS RESTRICTION: PASTORS CANNOT POST PROJECTS/POSTS IF DISTRICT IS NOT ACTIVE
CREATE OR REPLACE FUNCTION pastor_district_is_active(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM profiles p
        JOIN districts d ON p.district_id = d.id
        WHERE p.id = p_user_id
          AND d.status = 'active'
    );
$$;

-- Drop old post insert policies if needed and apply active district constraint
DROP POLICY IF EXISTS "Pastors can create posts" ON posts;
CREATE POLICY "Pastors can create posts"
    ON posts FOR INSERT
    TO authenticated
    WITH CHECK (
        is_pastor() AND
        author_id = auth.uid() AND
        pastor_district_is_active(auth.uid())
    );

DROP POLICY IF EXISTS "Pastors can create projects" ON projects;
CREATE POLICY "Pastors can create projects"
    ON projects FOR INSERT
    TO authenticated
    WITH CHECK (
        is_pastor() AND
        created_by = auth.uid() AND
        pastor_district_is_active(auth.uid())
    );

-- 8. STORED PROCEDURES FOR DISTRICT REGISTRATION & APPROVAL
CREATE OR REPLACE FUNCTION register_district_by_pastor(
    p_name TEXT,
    p_assemblies TEXT[],
    p_start_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

    v_clean_name := regexp_replace(trim(p_name), '\s+', ' ', 'g');
    IF length(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Please enter a valid district name.';
    END IF;

    -- Check for duplicate district name
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
        submitted_at
    ) VALUES (
        v_clean_name,
        'pending',
        v_pastor_id,
        now()
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

-- Stored Procedure: Approve District
CREATE OR REPLACE FUNCTION approve_district(
    p_district_id UUID,
    p_decision_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
    v_district RECORD;
    v_pastor_id UUID;
BEGIN
    v_admin_id := auth.uid();
    IF NOT is_area_head() THEN
        RAISE EXCEPTION 'Only the Area Head can approve districts.';
    END IF;

    SELECT * INTO v_district FROM districts WHERE id = p_district_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'District not found.';
    END IF;

    -- Update district status
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
    IF v_pastor_id IS NOT NULL THEN
        INSERT INTO pastor_tenures (
            pastor_id,
            district_id,
            start_date,
            status
        ) VALUES (
            v_pastor_id,
            p_district_id,
            CURRENT_DATE,
            'active'
        ) ON CONFLICT DO NOTHING;

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

-- Stored Procedure: Reject District
CREATE OR REPLACE FUNCTION reject_district(
    p_district_id UUID,
    p_decision_note TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

    -- Update district status
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
