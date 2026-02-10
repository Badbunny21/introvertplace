-- Community posts table
CREATE TABLE IF NOT EXISTS community_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT, -- Optional image attachment
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_community_posts_community ON community_posts(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_author ON community_posts(author_id);

-- Enable Row Level Security
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view posts in public communities
-- For private communities, only members can view (we'll keep it simple for now - all viewable)
CREATE POLICY "Anyone can view community posts" ON community_posts
  FOR SELECT USING (true);

-- Policy: Community members can create posts
-- (We check membership in the app layer for simplicity, but allow inserts for authenticated users)
CREATE POLICY "Authenticated users can create posts" ON community_posts
  FOR INSERT WITH CHECK (auth.uid() = author_id);

-- Policy: Authors can update their own posts
CREATE POLICY "Authors can update own posts" ON community_posts
  FOR UPDATE USING (auth.uid() = author_id);

-- Policy: Authors can delete their own posts
CREATE POLICY "Authors can delete own posts" ON community_posts
  FOR DELETE USING (auth.uid() = author_id);

-- Optional: Add is_private column to communities if not exists
ALTER TABLE communities ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;
