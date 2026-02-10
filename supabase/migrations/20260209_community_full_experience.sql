-- ============================================
-- IntrovertPlace Community Full Experience
-- A cozy space for introverts to connect, 
-- create, learn, and share at their own pace
-- ============================================

-- Drop the basic posts table if it exists and recreate with full features
-- (Skip if you already have data you want to keep)

-- ============================================
-- POSTS TABLE (Enhanced)
-- ============================================
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS post_type TEXT DEFAULT 'thought';
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS link_url TEXT;
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS link_title TEXT;
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

-- Post types:
-- 'thought' - casual sharing, reflections 💭
-- 'resource' - links, book recs, articles 📚
-- 'creation' - art, writing, photos ✨
-- 'lesson' - teach something 🎓
-- 'question' - ask the community ❓

COMMENT ON COLUMN community_posts.post_type IS 'Type of post: thought, resource, creation, lesson, question';

-- ============================================
-- COMMENTS TABLE
-- Threaded comments for meaningful conversations
-- ============================================
CREATE TABLE IF NOT EXISTS community_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  parent_id UUID REFERENCES community_comments(id) ON DELETE CASCADE, -- For nested replies
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON community_comments(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON community_comments(parent_id);

ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view comments" ON community_comments
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can comment" ON community_comments
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own comments" ON community_comments
  FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Authors can delete own comments" ON community_comments
  FOR DELETE USING (auth.uid() = author_id);

-- ============================================
-- REACTIONS TABLE
-- Quiet appreciation - soft, meaningful reactions
-- ============================================
CREATE TABLE IF NOT EXISTS post_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reaction TEXT NOT NULL, -- 'appreciate', 'thoughtful', 'helpful', 'support'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id, reaction)
);

CREATE INDEX IF NOT EXISTS idx_reactions_post ON post_reactions(post_id);

ALTER TABLE post_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reactions" ON post_reactions
  FOR SELECT USING (true);

CREATE POLICY "Users can add reactions" ON post_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own reactions" ON post_reactions
  FOR DELETE USING (auth.uid() = user_id);

-- Reaction types:
-- 'appreciate' ✨ - love this, beautiful
-- 'thoughtful' 💭 - made me think
-- 'helpful' 🌱 - learned something
-- 'support' 💜 - I feel you, solidarity

-- ============================================
-- BOOKMARKS TABLE
-- Save posts to read later (introvert essential!)
-- ============================================
CREATE TABLE IF NOT EXISTS post_bookmarks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON post_bookmarks(user_id, created_at DESC);

ALTER TABLE post_bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks" ON post_bookmarks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can add bookmarks" ON post_bookmarks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own bookmarks" ON post_bookmarks
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Get reaction counts for a post
CREATE OR REPLACE FUNCTION get_post_reactions(p_post_id UUID)
RETURNS TABLE(reaction TEXT, count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT pr.reaction, COUNT(*)::BIGINT
  FROM post_reactions pr
  WHERE pr.post_id = p_post_id
  GROUP BY pr.reaction;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get comment count for a post
CREATE OR REPLACE FUNCTION get_comment_count(p_post_id UUID)
RETURNS BIGINT AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM community_comments WHERE post_id = p_post_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
