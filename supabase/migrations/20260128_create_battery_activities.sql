-- Create battery_activities table for persisting social battery drain logs
CREATE TABLE IF NOT EXISTS battery_activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  icon TEXT DEFAULT '📋',
  drain INTEGER NOT NULL,
  logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE battery_activities ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own activities
CREATE POLICY "Users can view own activities" ON battery_activities
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own activities
CREATE POLICY "Users can create activities" ON battery_activities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own activities
CREATE POLICY "Users can delete own activities" ON battery_activities
  FOR DELETE USING (auth.uid() = user_id);
