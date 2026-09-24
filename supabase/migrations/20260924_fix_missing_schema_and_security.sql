-- ============================================================
-- 2026-09-24: Apply schema the front end already expects but
-- that never reached production, plus security hardening.
-- Idempotent: safe to re-run.
-- ============================================================

-- 1. Profile preferences (from 20260225_add_profile_preferences, never applied)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS theme TEXT DEFAULT 'dark';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS font_size TEXT DEFAULT 'medium';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reduce_animations BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_start TEXT DEFAULT '22:00';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_end TEXT DEFAULT '08:00';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS discovery_mode TEXT DEFAULT 'selective';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS welcome_responses TEXT[] DEFAULT '{}';

-- 2. Garden room privacy (from 20260328_garden_room_privacy, never applied)
ALTER TABLE garden_rooms ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
UPDATE garden_rooms SET is_public = true WHERE is_system_room = true;
CREATE INDEX IF NOT EXISTS garden_rooms_public_idx ON garden_rooms(is_public) WHERE is_public = true;

-- 3. Visit counter RPC (from 20260225_add_increment_visit_count, never applied)
CREATE OR REPLACE FUNCTION public.increment_visit_count(room_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.garden_rooms
  SET visit_count = COALESCE(visit_count, 0) + 1, updated_at = now()
  WHERE id = room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. Community features (from 20260221_enhance_community_features, never applied)
ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS comfort_mode TEXT DEFAULT 'occasional'
    CHECK (comfort_mode IN ('lurk', 'occasional', 'active')),
  ADD COLUMN IF NOT EXISTS notification_level TEXT DEFAULT 'important'
    CHECK (notification_level IN ('off', 'digest', 'important')),
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();
CREATE INDEX IF NOT EXISTS community_members_community_id_idx ON community_members(community_id);
CREATE INDEX IF NOT EXISTS community_members_user_id_idx ON community_members(user_id);

ALTER TABLE communities
  ADD COLUMN IF NOT EXISTS allow_anonymous_posts BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS slow_mode BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS slow_mode_minutes INTEGER DEFAULT 60;

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
DROP POLICY IF EXISTS "Community rooms viewable by everyone" ON community_rooms;
CREATE POLICY "Community rooms viewable by everyone" ON community_rooms FOR SELECT USING (true);
DROP POLICY IF EXISTS "Community creator can create rooms" ON community_rooms;
CREATE POLICY "Community creator can create rooms" ON community_rooms FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid())
    OR EXISTS (SELECT 1 FROM community_members
               WHERE community_id = community_rooms.community_id
                 AND user_id = auth.uid() AND role IN ('owner', 'moderator')));
DROP POLICY IF EXISTS "Community owner can update rooms" ON community_rooms;
CREATE POLICY "Community owner can update rooms" ON community_rooms FOR UPDATE
  USING (EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid()));
DROP POLICY IF EXISTS "Community owner can delete rooms" ON community_rooms;
CREATE POLICY "Community owner can delete rooms" ON community_rooms FOR DELETE
  USING (EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid()));

ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES community_rooms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;
CREATE INDEX IF NOT EXISTS community_posts_room_id_idx ON community_posts(room_id);
CREATE INDEX IF NOT EXISTS community_posts_community_created_idx ON community_posts(community_id, created_at DESC);

-- App admins (site-wide moderation). Seeded with the founder account.
CREATE TABLE IF NOT EXISTS app_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE app_admins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can see themselves" ON app_admins;
CREATE POLICY "Admins can see themselves" ON app_admins FOR SELECT TO authenticated USING (user_id = auth.uid());
INSERT INTO app_admins (user_id) VALUES ('1a6e594b-6b76-420d-ba17-06c2ec8c76aa') ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_app_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = auth.uid());
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

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
DROP POLICY IF EXISTS "Authenticated users can submit reports" ON community_reports;
CREATE POLICY "Authenticated users can submit reports" ON community_reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);
DROP POLICY IF EXISTS "Reporters and community owners can view reports" ON community_reports;
CREATE POLICY "Reporters and community owners can view reports" ON community_reports FOR SELECT
  USING (auth.uid() = reporter_id OR public.is_app_admin()
         OR EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid()));
DROP POLICY IF EXISTS "Community owner can update report status" ON community_reports;
CREATE POLICY "Community owner can update report status" ON community_reports FOR UPDATE
  USING (public.is_app_admin()
         OR EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid()));

-- Admins can remove reported posts
DROP POLICY IF EXISTS "App admins can delete posts" ON community_posts;
CREATE POLICY "App admins can delete posts" ON community_posts FOR DELETE USING (public.is_app_admin());

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
DROP POLICY IF EXISTS "Community owners can manage bans" ON community_bans;
CREATE POLICY "Community owners can manage bans" ON community_bans FOR ALL
  USING (EXISTS (SELECT 1 FROM communities WHERE id = community_id AND creator_id = auth.uid()));
DROP POLICY IF EXISTS "Users can check if they are banned" ON community_bans;
CREATE POLICY "Users can check if they are banned" ON community_bans FOR SELECT USING (auth.uid() = user_id);

-- 5. Profiles: members only (was readable by anyone on the internet)
DROP POLICY IF EXISTS "Anyone can view profiles" ON profiles;
DROP POLICY IF EXISTS "Members can view profiles" ON profiles;
CREATE POLICY "Members can view profiles" ON profiles FOR SELECT TO authenticated USING (true);

-- 6. Beta feedback: no more always-true insert; no reading anonymous rows
DROP POLICY IF EXISTS "Users can submit feedback" ON beta_feedback;
CREATE POLICY "Users can submit feedback" ON beta_feedback FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can view own feedback" ON beta_feedback;
CREATE POLICY "Users can view own feedback" ON beta_feedback FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_app_admin());

-- 7. Notifications: sender must be signed in; recipients can mark read
DROP POLICY IF EXISTS "Users can mark notifications seen" ON notifications;
CREATE POLICY "Users can mark notifications seen" ON notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS notifications_user_unseen_idx ON notifications(user_id, seen, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_recipient_read_idx ON messages(recipient_id, read);

-- 8. Pin search_path on every public function (Security Advisor warnings)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.prokind = 'f'
             AND (p.proconfig IS NULL OR NOT EXISTS (
                  SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'))
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.sig);
  END LOOP;
END $$;

-- 9. Realtime for messages and notifications
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;
