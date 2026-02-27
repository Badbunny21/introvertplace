-- Add profile preference columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS theme TEXT DEFAULT 'dark';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS font_size TEXT DEFAULT 'medium';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reduce_animations BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_start TEXT DEFAULT '22:00';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quiet_hours_end TEXT DEFAULT '08:00';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS discovery_mode TEXT DEFAULT 'selective';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS welcome_responses TEXT[] DEFAULT '{}';
