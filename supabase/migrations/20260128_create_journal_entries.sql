-- Create journal_entries table
CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  mood TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only view their own journal entries
CREATE POLICY "Users can view own journal entries" ON journal_entries
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Authenticated users can create their own journal entries
CREATE POLICY "Users can create own journal entries" ON journal_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own journal entries
CREATE POLICY "Users can update own journal entries" ON journal_entries
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own journal entries
CREATE POLICY "Users can delete own journal entries" ON journal_entries
  FOR DELETE USING (auth.uid() = user_id);
