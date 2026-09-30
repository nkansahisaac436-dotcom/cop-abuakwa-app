-- ============================================================================
-- Seed: 01_ministries_seed.sql
-- Description: Pre-populates the 5 core ministries of The Church of Pentecost
-- ============================================================================

INSERT INTO ministries (id, name, code, description, icon_name)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Youth', 'youth', 'Youth Ministry: Equipping youth for Christ and Area evangelism.', 'people'),
  ('a0000000-0000-0000-0000-000000000002', 'Evangelism', 'evangelism', 'Evangelism Ministry: Reaching communities and soul-winning across Abuakwa Area.', 'campaign'),
  ('a0000000-0000-0000-0000-000000000003', 'Children''s', 'childrens', 'Children''s Ministry: Nurturing the faith and biblical foundation of children.', 'child_care'),
  ('a0000000-0000-0000-0000-000000000004', 'Pemem', 'pemem', 'Pentecost Men''s Movement (PEMEM): Fostering godly brotherhood and leadership.', 'shield'),
  ('a0000000-0000-0000-0000-000000000005', 'Women''s', 'womens', 'Women''s Ministry: Empowering women in faith, discipleship and service.', 'favorite')
ON CONFLICT (name) DO UPDATE
SET description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;
