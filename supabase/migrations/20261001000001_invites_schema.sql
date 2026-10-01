-- ============================================================================
-- Migration: 20261001000001_invites_schema.sql
-- Description: Creates invites table, RLS rules, and stored procedures for
--              invite code verification, redemption, and tenure initiation.
-- ============================================================================

-- 1. Create invites table
CREATE TABLE IF NOT EXISTS invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_hash TEXT NOT NULL UNIQUE,
    code_display TEXT NOT NULL,
    role user_role NOT NULL CHECK (role IN ('pastor', 'ministry_leader')),
    target_name TEXT NOT NULL,
    district_id UUID REFERENCES districts(id) ON DELETE SET NULL,
    ministry_id TEXT REFERENCES ministries(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'redeemed', 'cancelled', 'expired')),
    attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
    redeemed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    redeemed_at TIMESTAMPTZ
);

-- Index for code lookups & expiration queries
CREATE INDEX IF NOT EXISTS idx_invites_code_hash ON invites(code_hash);
CREATE INDEX IF NOT EXISTS idx_invites_status_expires ON invites(status, expires_at);
CREATE INDEX IF NOT EXISTS idx_invites_created_by ON invites(created_by);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;

-- Area Head can view, create, and update all invites
CREATE POLICY "Area Head can manage all invites"
    ON invites
    FOR ALL
    TO authenticated
    USING (is_area_head())
    WITH CHECK (is_area_head());

-- 3. Stored Procedure: Verify Invite Code (SECURITY DEFINER for anon/auth verification)
CREATE OR REPLACE FUNCTION verify_invite_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_code TEXT;
    v_invite RECORD;
    v_district_name TEXT := NULL;
    v_ministry_name TEXT := NULL;
BEGIN
    v_clean_code := UPPER(TRIM(p_code));

    -- Look up invite by code
    SELECT * INTO v_invite
    FROM invites
    WHERE code_display = v_clean_code OR code_hash = v_clean_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'This code is not valid. Ask your Area Head for a new one.';
    END IF;

    -- Check if rate-limited / locked out (15 minutes after 5 failed tries)
    IF v_invite.locked_until IS NOT NULL AND v_invite.locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts. Try again in 15 minutes.';
    END IF;

    -- Check status and expiration
    IF v_invite.status != 'pending' OR v_invite.expires_at <= now() THEN
        -- Mark as expired if past expiration date
        IF v_invite.status = 'pending' AND v_invite.expires_at <= now() THEN
            UPDATE invites SET status = 'expired' WHERE id = v_invite.id;
        END IF;
        RAISE EXCEPTION 'This code is not valid. Ask your Area Head for a new one.';
    END IF;

    -- Fetch district or ministry display names
    IF v_invite.district_id IS NOT NULL THEN
        SELECT name INTO v_district_name FROM districts WHERE id = v_invite.district_id;
    END IF;

    IF v_invite.ministry_id IS NOT NULL THEN
        SELECT name INTO v_ministry_name FROM ministries WHERE id = v_invite.ministry_id;
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'invite_id', v_invite.id,
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

-- 4. Stored Procedure: Redeem Invite (Atomic Activation)
CREATE OR REPLACE FUNCTION redeem_invite(
    p_code TEXT,
    p_user_id UUID,
    p_email TEXT,
    p_full_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_code TEXT;
    v_invite RECORD;
    v_tenure_id UUID;
BEGIN
    v_clean_code := UPPER(TRIM(p_code));

    -- Lock the invite row for update
    SELECT * INTO v_invite
    FROM invites
    WHERE (code_display = v_clean_code OR code_hash = v_clean_code)
      AND status = 'pending'
      AND expires_at > now()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'This code is not valid. Ask your Area Head for a new one.';
    END IF;

    -- 1. Create or update profile
    INSERT INTO profiles (
        id,
        full_name,
        email,
        role,
        status,
        district_id,
        created_at
    ) VALUES (
        p_user_id,
        COALESCE(NULLIF(p_full_name, ''), v_invite.target_name),
        LOWER(TRIM(p_email)),
        v_invite.role,
        'active',
        v_invite.district_id,
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        status = 'active',
        district_id = EXCLUDED.district_id,
        full_name = EXCLUDED.full_name;

    -- 2. If Pastor: Initiate active tenure
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
        ) RETURNING id INTO v_tenure_id;
    END IF;

    -- 3. If Ministry Leader: Link ministry leadership
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
