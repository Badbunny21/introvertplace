-- Create community_members junction table for tracking which users joined which communities
CREATE TABLE IF NOT EXISTS community_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, community_id)
);

-- Enable Row Level Security
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view community memberships
CREATE POLICY "Anyone can view community members" ON community_members
  FOR SELECT USING (true);

-- Policy: Authenticated users can join communities
CREATE POLICY "Users can join communities" ON community_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can leave communities they joined
CREATE POLICY "Users can leave communities" ON community_members
  FOR DELETE USING (auth.uid() = user_id);

-- Add pinned_creation column to profiles if not exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pinned_creation_id UUID;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pinned_creation_type TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pinned_creation_title TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pinned_creation_preview TEXT;
