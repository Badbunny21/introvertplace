-- Add is_public flag to garden_rooms
-- Rooms are private by default — owners must explicitly make them discoverable.
-- System rooms (is_system_room = true) are always public.
ALTER TABLE garden_rooms
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;

-- System rooms should be publicly visible
UPDATE garden_rooms SET is_public = true WHERE is_system_room = true;

-- Index for fast public-room queries
CREATE INDEX IF NOT EXISTS garden_rooms_public_idx ON garden_rooms(is_public) WHERE is_public = true;
