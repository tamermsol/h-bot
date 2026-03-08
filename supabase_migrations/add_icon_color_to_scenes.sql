-- Add icon and color fields to scenes table
-- This allows storing the user-selected icon and color for each scene

-- 1) icon_code can stay INTEGER
ALTER TABLE scenes
ADD COLUMN IF NOT EXISTS icon_code INTEGER;

-- 2) color_value MUST be BIGINT (Flutter Color.value can exceed int32)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name='scenes' AND column_name='color_value'
  ) THEN
    ALTER TABLE scenes ADD COLUMN color_value BIGINT;
  ELSE
    -- if it exists but is INTEGER, upgrade it
    IF (SELECT data_type
        FROM information_schema.columns
        WHERE table_name='scenes' AND column_name='color_value') = 'integer' THEN
      ALTER TABLE scenes
      ALTER COLUMN color_value TYPE BIGINT USING color_value::bigint;
    END IF;
  END IF;
END $$;

COMMENT ON COLUMN scenes.icon_code IS 'Flutter IconData codePoint (int)';
COMMENT ON COLUMN scenes.color_value IS 'Flutter Color.value (ARGB) stored as bigint';

-- Defaults (example)
UPDATE scenes
SET
  icon_code = COALESCE(icon_code, 57535),
  color_value = COALESCE(color_value, 4282339571::bigint);
