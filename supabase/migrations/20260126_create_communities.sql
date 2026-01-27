-- Create communities table
CREATE TABLE IF NOT EXISTS communities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'General',
  icon TEXT DEFAULT '🏠',
  creator_id UUID REFERENCES auth.users(id),
  member_count INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view communities
CREATE POLICY "Anyone can view communities" ON communities
  FOR SELECT USING (true);

-- Policy: Anyone can create communities (for now, can restrict to authenticated later)
CREATE POLICY "Anyone can create communities" ON communities
  FOR INSERT WITH CHECK (true);

-- Policy: Creators can update their own communities
CREATE POLICY "Creators can update own communities" ON communities
  FOR UPDATE USING (auth.uid() = creator_id);

-- Policy: Creators can delete their own communities
CREATE POLICY "Creators can delete own communities" ON communities
  FOR DELETE USING (auth.uid() = creator_id);
