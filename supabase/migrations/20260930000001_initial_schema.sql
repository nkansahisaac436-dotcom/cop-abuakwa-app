-- ============================================================================
-- Migration: 20260930000001_initial_schema.sql
-- Description: Creates enums, tables, foreign keys, and indexes for Abuakwa Area Connect
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUMS
CREATE TYPE user_role AS ENUM (
    'area_head',
    'pastor',
    'ministry_leader',
    'member'
);

CREATE TYPE profile_status AS ENUM (
    'active',
    'transferred',
    'suspended'
);

CREATE TYPE visibility_level AS ENUM (
    'public',
    'members',
    'pastors',
    'area_head'
);

CREATE TYPE district_status AS ENUM (
    'inactive',
    'active'
);

CREATE TYPE project_type AS ENUM (
    'project',
    'event'
);

CREATE TYPE project_status AS ENUM (
    'planned',
    'ongoing',
    'completed'
);

CREATE TYPE transfer_status AS ENUM (
    'pending',
    'approved',
    'rejected'
);

CREATE TYPE tenure_status AS ENUM (
    'active',
    'archived'
);

CREATE TYPE post_type AS ENUM (
    'announcement',
    'thought',
    'news'
);

CREATE TYPE media_kind AS ENUM (
    'image',
    'pdf'
);

-- 2. DISTRICTS TABLE
CREATE TABLE districts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL UNIQUE,
    status district_status NOT NULL DEFAULT 'inactive',
    activated_by UUID,
    activated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. ASSEMBLIES TABLE (Local assemblies within a district)
CREATE TABLE assemblies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    district_id UUID NOT NULL REFERENCES districts(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    location_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_assembly_per_district UNIQUE (district_id, name)
);

-- 4. PROFILES TABLE (Linked with Supabase Auth users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(30),
    role user_role NOT NULL DEFAULT 'member',
    status profile_status NOT NULL DEFAULT 'active',
    district_id UUID REFERENCES districts(id) ON DELETE SET NULL,
    assembly_id UUID REFERENCES assemblies(id) ON DELETE SET NULL,
    avatar_url TEXT,
    data_consent_accepted BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign key constraint for activated_by on districts after profiles exists
ALTER TABLE districts
    ADD CONSTRAINT fk_districts_activated_by
    FOREIGN KEY (activated_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- 5. MINISTRIES TABLE (Youth, Evangelism, Children's, Pemem, Women's)
CREATE TABLE ministries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    icon_name VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. MINISTRY LEADERS TABLE
CREATE TABLE ministry_leaders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    ministry_id UUID NOT NULL REFERENCES ministries(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_ministry_leader UNIQUE (user_id, ministry_id)
);

-- 7. MINISTRY FOLLOWS TABLE
CREATE TABLE ministry_follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    ministry_id UUID NOT NULL REFERENCES ministries(id) ON DELETE CASCADE,
    followed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_ministry_follow UNIQUE (user_id, ministry_id)
);

-- 8. PASTOR TENURES TABLE
CREATE TABLE pastor_tenures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pastor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    district_id UUID NOT NULL REFERENCES districts(id) ON DELETE CASCADE,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    status tenure_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. PROJECTS TABLE
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    district_id UUID NOT NULL REFERENCES districts(id) ON DELETE CASCADE,
    assembly_id UUID REFERENCES assemblies(id) ON DELETE SET NULL,
    tenure_id UUID REFERENCES pastor_tenures(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    type project_type NOT NULL DEFAULT 'project',
    status project_status NOT NULL DEFAULT 'planned',
    progress_pct INTEGER NOT NULL DEFAULT 0 CHECK (progress_pct >= 0 AND progress_pct <= 100),
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    start_date DATE,
    end_date DATE,
    visibility visibility_level NOT NULL DEFAULT 'members',
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. PROJECT UPDATES TABLE
CREATE TABLE project_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    note TEXT NOT NULL,
    progress_pct INTEGER NOT NULL CHECK (progress_pct >= 0 AND progress_pct <= 100),
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. MEDIA TABLE
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_type VARCHAR(50) NOT NULL, -- e.g. 'project', 'project_update', 'post', 'profile'
    owner_id UUID NOT NULL,
    url TEXT NOT NULL,
    kind media_kind NOT NULL DEFAULT 'image',
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. VISITS TABLE (Area Head Supervision Log)
CREATE TABLE visits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    district_id UUID REFERENCES districts(id) ON DELETE CASCADE,
    visited_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT NOT NULL,
    visibility visibility_level NOT NULL DEFAULT 'area_head',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. POSTS TABLE (Announcements, Thoughts, News)
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type post_type NOT NULL DEFAULT 'news',
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    visibility visibility_level NOT NULL DEFAULT 'public',
    ministry_id UUID REFERENCES ministries(id) ON DELETE SET NULL,
    district_id UUID REFERENCES districts(id) ON DELETE SET NULL,
    tenure_id UUID REFERENCES pastor_tenures(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. MEETINGS TABLE (Jitsi Room Links)
CREATE TABLE meetings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    room_link TEXT NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    audience user_role NOT NULL DEFAULT 'pastor',
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 15. TRANSFER REQUESTS TABLE
CREATE TABLE transfer_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pastor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tenure_id UUID NOT NULL REFERENCES pastor_tenures(id) ON DELETE CASCADE,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status transfer_status NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    decided_at TIMESTAMPTZ,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. TENURE ARCHIVES TABLE (Read-Only Transferred Pastor Archive)
CREATE TABLE tenure_archives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenure_id UUID NOT NULL UNIQUE REFERENCES pastor_tenures(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL, -- e.g. "Pastor Enoch Agyemang, 2021-2026"
    summary_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    pdf_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. NOTIFICATIONS TABLE
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 18. DEVICE TOKENS TABLE
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(50) NOT NULL, -- 'android', 'ios', 'web'
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_token UNIQUE (user_id, token)
);

-- 19. AUDIT LOG TABLE
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'APPROVE_TRANSFER', etc.
    entity VARCHAR(100) NOT NULL, -- table name or domain concept
    entity_id UUID,
    payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX idx_districts_status ON districts(status);
CREATE INDEX idx_assemblies_district_id ON assemblies(district_id);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_district_id ON profiles(district_id);
CREATE INDEX idx_pastor_tenures_pastor_id ON pastor_tenures(pastor_id);
CREATE INDEX idx_pastor_tenures_district_id ON pastor_tenures(district_id);
CREATE INDEX idx_pastor_tenures_status ON pastor_tenures(status);
CREATE INDEX idx_projects_district_id ON projects(district_id);
CREATE INDEX idx_projects_visibility ON projects(visibility);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_project_updates_project_id ON project_updates(project_id);
CREATE INDEX idx_posts_visibility ON posts(visibility);
CREATE INDEX idx_posts_ministry_id ON posts(ministry_id);
CREATE INDEX idx_posts_district_id ON posts(district_id);
CREATE INDEX idx_transfer_requests_status ON transfer_requests(status);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, read);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
