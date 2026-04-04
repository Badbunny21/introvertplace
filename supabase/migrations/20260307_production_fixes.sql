-- ============================================================
-- Production fixes migration — 2026-03-07 (SAFE VERSION v2)
-- ============================================================

-- -------------------------------------------------------
-- 1. FIX: garden_visits RLS
-- -------------------------------------------------------
DROP POLICY IF EXISTS "Visits are viewable by room owner" ON garden_visits;

CREATE POLICY "Visits are viewable by room owner"
  ON garden_visits FOR SELECT
  USING (
    auth.uid() = (
      SELECT user_id FROM garden_rooms WHERE id = room_id
    )
  );

-- -------------------------------------------------------
-- 2. FIX: communities INSERT policy
-- -------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can create communities" ON communities;
DROP POLICY IF EXISTS "Authenticated users can create communities" ON communities;

CREATE POLICY "Authenticated users can create communities"
  ON communities
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- -------------------------------------------------------
-- 3. ADD: Missing indexes on user_id only
-- -------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_battery_activities_user_id
  ON battery_activities (user_id);

CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id
  ON journal_entries (user_id);

CREATE INDEX IF NOT EXISTS idx_mood_entries_user_id
  ON mood_entries (user_id);

CREATE INDEX IF NOT EXISTS idx_reflections_user_id
  ON reflections (user_id);

-- -------------------------------------------------------
-- 4. FIX: Guarantee community_members.role column exists
-- -------------------------------------------------------
ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'community_members_role_check'
  ) THEN
    ALTER TABLE community_members
      ADD CONSTRAINT community_members_role_check
      CHECK (role IN ('member', 'moderator', 'owner'));
  END IF;
END;
$$;

-- -------------------------------------------------------
-- 5. ADD: Auto-join community creator as owner
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auto_join_community_creator()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO community_members (community_id, user_id, role)
  VALUES (NEW.id, NEW.creator_id, 'owner')
  ON CONFLICT (user_id, community_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_join_community_creator ON communities;
CREATE TRIGGER trg_auto_join_community_creator
  AFTER INSERT ON communities
  FOR EACH ROW EXECUTE FUNCTION fn_auto_join_community_creator();

-- -------------------------------------------------------
-- 6. ADD: Keep member_count in sync
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_community_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE communities
      SET member_count = member_count + 1
      WHERE id = NEW.community_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE communities
      SET member_count = GREATEST(0, member_count - 1)
      WHERE id = OLD.community_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_community_member_count ON community_members;
CREATE TRIGGER trg_community_member_count
  AFTER INSERT OR DELETE ON community_members
  FOR EACH ROW EXECUTE FUNCTION fn_update_community_member_count();