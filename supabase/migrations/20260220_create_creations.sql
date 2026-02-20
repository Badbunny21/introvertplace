-- Creations table for all user-generated content across Creative page modes
CREATE TABLE IF NOT EXISTS creations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('writing', 'visual', 'music', 'idea')),
  title TEXT NOT NULL,
  content TEXT,
  description TEXT,
  mood TEXT,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'community', 'private')),
  view_mode TEXT DEFAULT 'constellation',
  garden_room_id UUID REFERENCES garden_rooms(id) ON DELETE SET NULL,
  cover_image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE creations ENABLE ROW LEVEL SECURITY;

-- Public creations visible to everyone
CREATE POLICY "Public creations are viewable by everyone"
  ON creations FOR SELECT
  USING (visibility = 'public');

-- Users can always see their own creations (public, community, or private)
CREATE POLICY "Users can see their own creations"
  ON creations FOR SELECT
  USING (auth.uid() = user_id);

-- Community creations visible to any authenticated user
CREATE POLICY "Community creations visible to authenticated users"
  ON creations FOR SELECT
  USING (auth.uid() IS NOT NULL AND visibility = 'community');

-- Users can insert their own creations
CREATE POLICY "Users can create their own creations"
  ON creations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own creations
CREATE POLICY "Users can update their own creations"
  ON creations FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own creations
CREATE POLICY "Users can delete their own creations"
  ON creations FOR DELETE
  USING (auth.uid() = user_id);

-- Performance indexes
CREATE INDEX IF NOT EXISTS creations_user_id_idx ON creations(user_id);
CREATE INDEX IF NOT EXISTS creations_visibility_idx ON creations(visibility);
CREATE INDEX IF NOT EXISTS creations_view_mode_idx ON creations(view_mode);
CREATE INDEX IF NOT EXISTS creations_garden_room_id_idx ON creations(garden_room_id);
CREATE INDEX IF NOT EXISTS creations_created_at_idx ON creations(created_at DESC);
