-- Add display_mode to profiles for creative page mode isolation
-- Values: constellation, garden, canvas, seasonal
-- NULL means user hasn't picked a mode yet → defaults to garden in app logic
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS display_mode TEXT
  CHECK (display_mode IN ('constellation', 'garden', 'canvas', 'seasonal'));

-- Index for fast mode-based filtering when loading creative content
CREATE INDEX IF NOT EXISTS profiles_display_mode_idx ON profiles(display_mode);
