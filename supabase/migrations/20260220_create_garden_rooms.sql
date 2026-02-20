-- Garden Rooms table for the Garden World feature
CREATE TABLE IF NOT EXISTS garden_rooms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  mood TEXT NOT NULL DEFAULT 'calm' CHECK (mood IN ('calm', 'dreamy', 'energetic', 'reflective')),
  emoji TEXT DEFAULT '🌱',
  gradient_colors TEXT[] DEFAULT ARRAY['rgba(124,232,168,0.3)', 'rgba(152,212,187,0.2)'],
  growth_level INTEGER DEFAULT 0 CHECK (growth_level >= 0 AND growth_level <= 100),
  visit_count INTEGER DEFAULT 0,
  appreciation_count INTEGER DEFAULT 0,
  is_system_room BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  position_x FLOAT DEFAULT 0,
  position_y FLOAT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE garden_rooms ENABLE ROW LEVEL SECURITY;

-- Anyone can read garden rooms (public gardens)
CREATE POLICY "Garden rooms are viewable by everyone"
  ON garden_rooms FOR SELECT
  USING (true);

-- Users can create their own rooms
CREATE POLICY "Users can create their own garden rooms"
  ON garden_rooms FOR INSERT
  WITH CHECK (auth.uid() = user_id OR is_system_room = true);

-- Users can update their own rooms
CREATE POLICY "Users can update their own garden rooms"
  ON garden_rooms FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own rooms
CREATE POLICY "Users can delete their own garden rooms"
  ON garden_rooms FOR DELETE
  USING (auth.uid() = user_id);

-- Garden room visits tracking
CREATE TABLE IF NOT EXISTS garden_visits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id UUID REFERENCES garden_rooms(id) ON DELETE CASCADE,
  visitor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  visited_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE garden_visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Visits are viewable by room owner"
  ON garden_visits FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can log visits"
  ON garden_visits FOR INSERT
  WITH CHECK (auth.uid() = visitor_id);

-- Seed system gardens (featured demo rooms)
INSERT INTO garden_rooms (name, description, mood, emoji, gradient_colors, growth_level, is_system_room, is_featured, position_x, position_y) VALUES
  ('Midnight Poetry Garden', 'A quiet corner where words bloom under moonlight. Leave a verse, take a breath.', 'dreamy', '🌙', ARRAY['rgba(196,161,255,0.4)', 'rgba(124,184,232,0.3)'], 75, true, true, -0.3, -0.2),
  ('Quiet Sketch Sanctuary', 'Pencil lines and soft shadows. A place for visual whispers.', 'calm', '🎨', ARRAY['rgba(232,168,124,0.4)', 'rgba(240,232,124,0.3)'], 60, true, true, 0.4, -0.1),
  ('Dream Archive Room', 'Collect fragments of dreams. Half-remembered images welcome.', 'dreamy', '💭', ARRAY['rgba(124,184,232,0.4)', 'rgba(196,161,255,0.3)'], 85, true, true, -0.1, 0.4),
  ('Morning Light Studio', 'Warm tones and gentle starts. Create before the world wakes.', 'energetic', '🌅', ARRAY['rgba(232,168,124,0.4)', 'rgba(124,232,168,0.3)'], 45, true, true, 0.3, 0.3),
  ('Reflection Pool', 'Still waters for deep thoughts. Write what surfaces.', 'reflective', '🪷', ARRAY['rgba(124,232,168,0.4)', 'rgba(124,184,232,0.3)'], 90, true, true, -0.4, 0.1);
