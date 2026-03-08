-- Add icon_name column to rooms table
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS icon_name TEXT;

-- Add comment
COMMENT ON COLUMN rooms.icon_name IS 'Material icon name for the room (e.g., bed, kitchen, bathtub)';
