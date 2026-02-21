-- ============================================
-- Enhance Community Features
-- Implements: comfort mode, notification level,
-- rooms, anonymous posting, reporting, banning
-- ============================================

-- ============================================
-- 1. Add comfort_mode, notification_level, role to community_members
-- ============================================
ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member'
    CHECK (role IN ('member', 'moderator', 'owner')),
  ADD COLUMN IF NOT EXISTS comfort_mode TEXT DEFAULT 'occasional'
    CHECK (comfort_mode IN ('lurk', 'occasional', 'active')),
  ADD COLUMN IF NOT EXISTS notification_level TEXT DEFAULT 'important'
    CHECK (notification_level IN ('off', 'digest', 'important')),
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS community_members_community_id_idx ON community_members(community_id);
CREATE INDEX IF NOT EXISTS community_members_user_id_idx ON community_members(user_id);

-- ============================================
-- 2. Add new settings columns to communities
-- ============================================
ALTER TABLE communities
  ADD COLUMN IF NOT EXISTS allow_anonymous_posts BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS slow_mode BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS slow_mode_minutes INTEGER DEFAULT 60;

-- ============================================
-- 3. Community Rooms table
-- ============================================
CREATE TABLE IF NOT EXISTS community_rooms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'custom'
    CHECK (type IN ('start_here', 'threads', 'prompts', 'resources', 'custom')),
  description TEXT,
  position_order INTEGER DEFAULT 0,
  is_read_only BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS community_rooms_community_id_idx ON community_rooms(community_id);

ALTER TABLE community_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Community rooms viewable by everyone"
  ON community_rooms FOR SELECT USING (true);

CREATE POLICY "Community creator can create rooms"
  ON community_rooms FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_id = community_rooms.community_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'moderator')
    )
  );

CREATE POLICY "Community owner can update rooms"
  ON community_rooms FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    )
  );

CREATE POLICY "Community owner can delete rooms"
  ON community_rooms FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    )
  );

-- ============================================
-- 4. Add room_id and is_anonymous to community_posts
-- ============================================
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES community_rooms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS community_posts_room_id_idx ON community_posts(room_id);
CREATE INDEX IF NOT EXISTS community_posts_community_created_idx ON community_posts(community_id, created_at DESC);

-- ============================================
-- 5. Community Reports table
-- ============================================
CREATE TABLE IF NOT EXISTS community_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES community_comments(id) ON DELETE CASCADE,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE community_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can submit reports"
  ON community_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Reporters and community owners can view reports"
  ON community_reports FOR SELECT
  USING (
    auth.uid() = reporter_id OR
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    )
  );

CREATE POLICY "Community owner can update report status"
  ON community_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    )
  );

-- ============================================
-- 6. Community Bans table
-- ============================================
CREATE TABLE IF NOT EXISTS community_bans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  banned_by UUID REFERENCES auth.users(id),
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id, user_id)
);

ALTER TABLE community_bans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Community owners can manage bans"
  ON community_bans FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM communities
      WHERE id = community_id AND creator_id = auth.uid()
    )
  );

CREATE POLICY "Users can check if they are banned"
  ON community_bans FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================
-- 7. Community Notifications table (simplified)
-- ============================================
CREATE TABLE IF NOT EXISTS community_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('reply', 'mention', 'prompt', 'moderation')),
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS community_notif_user_id_idx ON community_notifications(user_id, is_read, created_at DESC);

ALTER TABLE community_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON community_notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications"
  ON community_notifications FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can mark own notifications read"
  ON community_notifications FOR UPDATE
  USING (auth.uid() = user_id);
