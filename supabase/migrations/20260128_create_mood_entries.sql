-- Create mood_entries table
CREATE TABLE IF NOT EXISTS mood_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL,
  energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 10),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only view their own mood entries
CREATE POLICY "Users can view own mood entries" ON mood_entries
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Authenticated users can create their own mood entries
CREATE POLICY "Users can create own mood entries" ON mood_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own mood entries
CREATE POLICY "Users can update own mood entries" ON mood_entries
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own mood entries
CREATE POLICY "Users can delete own mood entries" ON mood_entries
  FOR DELETE USING (auth.uid() = user_id);
