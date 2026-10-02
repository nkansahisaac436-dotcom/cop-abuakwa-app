-- ============================================================================
-- Seed: 03_users_seed.sql
-- Description: Seeds the initial Area Head, Pastors, Ministry Leaders, and Members
--              in both auth.users and public.profiles with confirmed emails.
--              Idempotent: Safe to run multiple times without creating duplicates.
-- ============================================================================

-- Ensure pgcrypto extension is active for password hashing
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Function to safely upsert a Supabase auth user and corresponding profile
CREATE OR REPLACE FUNCTION seed_user(
    p_user_id UUID,
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role user_role,
    p_status profile_status DEFAULT 'active',
    p_district_id UUID DEFAULT NULL,
    p_assembly_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- 1. Insert or update auth.users
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        aud,
        role,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        crypt(p_password, gen_salt('bf')),
        NOW(),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', p_full_name),
        'authenticated',
        'authenticated',
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        encrypted_password = EXCLUDED.encrypted_password,
        email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
        confirmed_at = COALESCE(auth.users.confirmed_at, NOW()),
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        updated_at = NOW();

    -- Also ensure identities entry exists for email login
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        p_user_id,
        jsonb_build_object('sub', p_user_id::text, 'email', p_email),
        'email',
        p_email,
        NOW(),
        NOW(),
        NOW()
    )
    ON CONFLICT (provider, provider_id) DO UPDATE SET
        updated_at = NOW();

    -- 2. Insert or update public.profiles
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        role,
        status,
        district_id,
        assembly_id,
        data_consent_accepted,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        p_full_name,
        p_email,
        p_role,
        p_status,
        p_district_id,
        p_assembly_id,
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        district_id = EXCLUDED.district_id,
        assembly_id = EXCLUDED.assembly_id,
        updated_at = NOW();

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. SEED AREA HEAD (Apostle Area Head)
SELECT seed_user(
    '00000000-0000-0000-0000-000000000001'::UUID,
    'areahead@copabuakwa.org',
    'AbuakwaAreaHead2026!',
    'Apostle Area Head',
    'area_head'::user_role,
    'active'::profile_status
);

-- 2. SEED PASTOR (Pastor Enoch Agyemang - Abuakwa North District)
SELECT seed_user(
    '00000000-0000-0000-0000-000000000002'::UUID,
    'pastor@copabuakwa.org',
    'AbuakwaPastor2026!',
    'Pastor Enoch Agyemang',
    'pastor'::user_role,
    'active'::profile_status,
    'd0000000-0000-0000-0000-000000000002'::UUID
);

-- Ensure active pastor tenure exists
INSERT INTO public.pastor_tenures (
    pastor_id,
    district_id,
    start_date,
    status
) VALUES (
    '00000000-0000-0000-0000-000000000002'::UUID,
    'd0000000-0000-0000-0000-000000000002'::UUID,
    '2026-01-01',
    'active'
) ON CONFLICT DO NOTHING;

-- 3. SEED MINISTRY LEADER (Sister Grace Osei - Women's Ministry)
SELECT seed_user(
    '00000000-0000-0000-0000-000000000003'::UUID,
    'womenleader@copabuakwa.org',
    'AbuakwaLeader2026!',
    'Sister Grace Osei',
    'ministry_leader'::user_role,
    'active'::profile_status
);

-- Ensure ministry leader assignment exists
INSERT INTO public.ministry_leaders (
    user_id,
    ministry_id
) VALUES (
    '00000000-0000-0000-0000-000000000003'::UUID,
    'a0000000-0000-0000-0000-000000000005'::UUID
) ON CONFLICT DO NOTHING;

-- 4. SEED MEMBER (Kofi Mensah)
SELECT seed_user(
    '00000000-0000-0000-0000-000000000004'::UUID,
    'kofi@example.com',
    'AbuakwaMember2026!',
    'Kofi Mensah',
    'member'::user_role,
    'active'::profile_status,
    'd0000000-0000-0000-0000-000000000002'::UUID
);

-- Drop helper function after seeding
DROP FUNCTION IF EXISTS seed_user(UUID, TEXT, TEXT, TEXT, user_role, profile_status, UUID, UUID);
