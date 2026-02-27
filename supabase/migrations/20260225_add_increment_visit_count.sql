-- RPC function called by useGardenRooms.ts to increment a room's visit count.
-- Without this, visits are logged in garden_visits but the counter on the room never updates.
CREATE OR REPLACE FUNCTION increment_visit_count(room_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE garden_rooms
  SET visit_count = COALESCE(visit_count, 0) + 1,
      updated_at  = now()
  WHERE id = room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
