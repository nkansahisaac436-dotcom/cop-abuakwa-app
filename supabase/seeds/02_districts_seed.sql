-- ============================================================================
-- Seed: 02_districts_seed.sql
-- Description: Pre-loads the 33 Districts of Abuakwa Area (all inactive by default)
--              with initial local assemblies. Editable as needed.
-- ============================================================================

INSERT INTO districts (id, name, status)
VALUES
  ('d0000000-0000-0000-0000-000000000001', 'Abuakwa Central', 'inactive'),
  ('d0000000-0000-0000-0000-000000000002', 'Abuakwa North', 'inactive'),
  ('d0000000-0000-0000-0000-000000000003', 'Abuakwa South', 'inactive'),
  ('d0000000-0000-0000-0000-000000000004', 'Tanoso', 'inactive'),
  ('d0000000-0000-0000-0000-000000000005', 'Akropong', 'inactive'),
  ('d0000000-0000-0000-0000-000000000006', 'Sepaase', 'inactive'),
  ('d0000000-0000-0000-0000-000000000007', 'Nkawie', 'inactive'),
  ('d0000000-0000-0000-0000-000000000008', 'Toase', 'inactive'),
  ('d0000000-0000-0000-0000-000000000009', 'Nyinahini', 'inactive'),
  ('d0000000-0000-0000-0000-000000000010', 'Barekese', 'inactive'),
  ('d0000000-0000-0000-0000-000000000011', 'Asuofua', 'inactive'),
  ('d0000000-0000-0000-0000-000000000012', 'Atwima Koforidua', 'inactive'),
  ('d0000000-0000-0000-0000-000000000013', 'Denkyemuoso', 'inactive'),
  ('d0000000-0000-0000-0000-000000000014', 'Agogo - Abuakwa', 'inactive'),
  ('d0000000-0000-0000-0000-000000000015', 'Nwabiagya East', 'inactive'),
  ('d0000000-0000-0000-0000-000000000016', 'Nwabiagya South', 'inactive'),
  ('d0000000-0000-0000-0000-000000000017', 'Mpasatia', 'inactive'),
  ('d0000000-0000-0000-0000-000000000018', 'Agogo Central', 'inactive'),
  ('d0000000-0000-0000-0000-000000000019', 'Achiase', 'inactive'),
  ('d0000000-0000-0000-0000-000000000020', 'Manhyia - Abuakwa', 'inactive'),
  ('d0000000-0000-0000-0000-000000000021', 'Bokankye', 'inactive'),
  ('d0000000-0000-0000-0000-000000000022', 'Fufuo', 'inactive'),
  ('d0000000-0000-0000-0000-000000000023', 'Amanchia', 'inactive'),
  ('d0000000-0000-0000-0000-000000000024', 'Adankwame', 'inactive'),
  ('d0000000-0000-0000-0000-000000000025', 'Darbaa', 'inactive'),
  ('d0000000-0000-0000-0000-000000000026', 'Adwumakase', 'inactive'),
  ('d0000000-0000-0000-0000-000000000027', 'Asakraka', 'inactive'),
  ('d0000000-0000-0000-0000-000000000028', 'Hiawu Besease', 'inactive'),
  ('d0000000-0000-0000-0000-000000000029', 'Tabere', 'inactive'),
  ('d0000000-0000-0000-0000-000000000030', 'Owhim', 'inactive'),
  ('d0000000-0000-0000-0000-000000000031', 'Ntobroso', 'inactive'),
  ('d0000000-0000-0000-0000-000000000032', 'Gyankobaa', 'inactive'),
  ('d0000000-0000-0000-0000-000000000033', 'Dabaa New Site', 'inactive')
ON CONFLICT (name) DO NOTHING;

-- Seed Sample Assemblies for Districts
INSERT INTO assemblies (district_id, name, location_text)
VALUES
  -- Abuakwa Central Assemblies
  ('d0000000-0000-0000-0000-000000000001', 'Central Assembly', 'Abuakwa Main Road, Near Area Office'),
  ('d0000000-0000-0000-0000-000000000001', 'Bethel Assembly', 'Abuakwa Extension Block 4'),
  ('d0000000-0000-0000-0000-000000000001', 'Emmanuel Assembly', 'Abuakwa Low Cost'),
  ('d0000000-0000-0000-0000-000000000001', 'Grace Assembly', 'Abuakwa Housing Area'),

  -- Abuakwa North Assemblies
  ('d0000000-0000-0000-0000-000000000002', 'Peniel Assembly', 'North Abuakwa Junction'),
  ('d0000000-0000-0000-0000-000000000002', 'Shalom Assembly', 'Near Presby School'),

  -- Abuakwa South Assemblies
  ('d0000000-0000-0000-0000-000000000003', 'Calvary Assembly', 'Abuakwa South Station'),
  ('d0000000-0000-0000-0000-000000000003', 'Hebron Assembly', 'South Bypass Road'),

  -- Tanoso Assemblies
  ('d0000000-0000-0000-0000-000000000004', 'Tanoso Central Assembly', 'Tanoso Main Highway'),
  ('d0000000-0000-0000-0000-000000000004', 'Moriah Assembly', 'Tanoso New Site'),

  -- Akropong Assemblies
  ('d0000000-0000-0000-0000-000000000005', 'Akropong Central Assembly', 'Akropong Market Area'),
  ('d0000000-0000-0000-0000-000000000005', 'Rehoboth Assembly', 'Akropong Hill View'),

  -- Sepaase Assemblies
  ('d0000000-0000-0000-0000-000000000006', 'Sepaase Central Assembly', 'Sepaase Main Junction'),

  -- Nkawie Assemblies
  ('d0000000-0000-0000-0000-000000000007', 'Nkawie Central Assembly', 'Nkawie Hospital Road')
ON CONFLICT (district_id, name) DO NOTHING;
