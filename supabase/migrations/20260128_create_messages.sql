-- Create messages table for user-to-user messaging
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(sender_id, recipient_id, created_at DESC);

-- Enable Row Level Security
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view messages they sent or received
CREATE POLICY "Users can view own messages" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Policy: Users can send messages (insert as sender)
CREATE POLICY "Users can send messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Policy: Recipients can mark messages as read
CREATE POLICY "Recipients can update read status" ON messages
  FOR UPDATE USING (auth.uid() = recipient_id);

-- Policy: Users can delete their own sent messages
CREATE POLICY "Users can delete own messages" ON messages
  FOR DELETE USING (auth.uid() = sender_id);
