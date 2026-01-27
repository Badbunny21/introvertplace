-- Create blog_posts table for storing user blog posts
CREATE TABLE IF NOT EXISTS blog_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT,
  author_name TEXT,
  author_avatar TEXT DEFAULT '🌙',
  read_time TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view published blog posts
CREATE POLICY "Anyone can view blog posts" ON blog_posts
  FOR SELECT USING (true);

-- Policy: Authenticated users can create blog posts
CREATE POLICY "Users can create blog posts" ON blog_posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own blog posts
CREATE POLICY "Users can update own posts" ON blog_posts
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own blog posts
CREATE POLICY "Users can delete own posts" ON blog_posts
  FOR DELETE USING (auth.uid() = user_id);
