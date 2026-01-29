-- Create reflections table
CREATE TABLE IF NOT EXISTS reflections (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  prompt TEXT,
  response TEXT NOT NULL,
  reflection_type TEXT DEFAULT 'prompt',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE reflections ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only view their own reflections
CREATE POLICY "Users can view own reflections" ON reflections
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Authenticated users can create their own reflections
CREATE POLICY "Users can create own reflections" ON reflections
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own reflections
CREATE POLICY "Users can update own reflections" ON reflections
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own reflections
CREATE POLICY "Users can delete own reflections" ON reflections
  FOR DELETE USING (auth.uid() = user_id);
