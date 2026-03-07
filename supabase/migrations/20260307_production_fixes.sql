-- ============================================================
-- Production fixes migration — 2026-03-07
-- Fixes: RLS policy gaps, missing indexes, auth holes
-- ============================================================

-- -------------------------------------------------------
-- 1. FIX: garden_visits SELECT policy says "room owner"
--    but uses USING(true) — everyone can see all visits.
--    Restrict to the room's owner only.
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
-- 2. FIX: communities INSERT policy had no auth check —
--    unauthenticated users could create communities.
-- -------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can create communities" ON communities;

CREATE POLICY "Authenticated users can create communities"
  ON communities
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- -------------------------------------------------------
-- 3. FIX: community_notifications INSERT policy used
--    WITH CHECK (true), allowing unauthenticated inserts.
-- -------------------------------------------------------
DROP POLICY IF EXISTS "System can insert notifications" ON community_notifications;

CREATE POLICY "Authenticated users can insert notifications"
  ON community_notifications
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- -------------------------------------------------------
-- 4. ADD: Missing indexes on user_id columns for tables
--    that are queried heavily per-user.
-- -------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_battery_activities_user_id
  ON battery_activities (user_id);

CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id
  ON journal_entries (user_id);

CREATE INDEX IF NOT EXISTS idx_mood_entries_user_id
  ON mood_entries (user_id);

CREATE INDEX IF NOT EXISTS idx_reflections_user_id
  ON reflections (user_id);

-- Also index created_at for time-based ordering queries
CREATE INDEX IF NOT EXISTS idx_journal_entries_created_at
  ON journal_entries (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mood_entries_created_at
  ON mood_entries (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reflections_created_at
  ON reflections (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_battery_activities_created_at
  ON battery_activities (created_at DESC);
