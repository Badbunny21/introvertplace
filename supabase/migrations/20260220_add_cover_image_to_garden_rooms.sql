-- Add cover_image_url to garden_rooms table
ALTER TABLE garden_rooms
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
