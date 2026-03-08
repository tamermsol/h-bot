-- =====================================================
-- Add Channel Type Support (Light or Switch)
-- Simple version - Run this in Supabase SQL Editor
-- =====================================================

-- Step 1: Add channel_type column with 'light' as default
ALTER TABLE device_channels 
ADD COLUMN IF NOT EXISTS channel_type TEXT NOT NULL DEFAULT 'light';

-- Step 2: Add check constraint to ensure valid channel types
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_channel_type'
  ) THEN
    ALTER TABLE device_channels
    ADD CONSTRAINT check_channel_type 
    CHECK (channel_type IN ('light', 'switch'));
  END IF;
END $$;

-- Step 3: Create index for performance
CREATE INDEX IF NOT EXISTS device_channels_channel_type_idx 
ON device_channels(channel_type);

-- Step 4: Create function to update channel type
CREATE OR REPLACE FUNCTION public.update_channel_type(
  p_device_id UUID,
  p_channel_no INT,
  p_channel_type TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner UUID := auth.uid();
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_channel_type NOT IN ('light', 'switch') THEN
    RAISE EXCEPTION 'invalid channel type: must be light or switch';
  END IF;

  -- Check device ownership
  IF NOT EXISTS (SELECT 1 FROM devices WHERE id = p_device_id AND owner_user_id = v_owner) THEN
    RAISE EXCEPTION 'device not found or access denied';
  END IF;

  -- Update channel type
  UPDATE device_channels
  SET channel_type = p_channel_type,
      updated_at = now()
  WHERE device_id = p_device_id 
    AND channel_no = p_channel_no;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'channel not found';
  END IF;
END $$;

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION public.update_channel_type TO authenticated;

-- Step 6: Update the devices_with_channels view to include channel_type
DROP VIEW IF EXISTS devices_with_channels;

CREATE OR REPLACE VIEW devices_with_channels AS
SELECT
    d.id,
    d.topic_base as tasmota_topic_base,
    d.topic_base,
    d.mac_address,
    d.owner_user_id,
    d.display_name as name,
    d.display_name,
    d.name_is_custom,
    d.channels,
    d.home_id,
    d.room_id,
    d.device_type,
    d.matter_type,
    d.meta_json,
    d.inserted_at as created_at,
    d.inserted_at,
    d.updated_at,
    COALESCE(
        (
            SELECT jsonb_object_agg(dc.channel_no::text,
                jsonb_build_object(
                    'label', dc.label,
                    'is_custom', dc.label_is_custom,
                    'type', dc.channel_type
                )
            )
            FROM device_channels dc
            WHERE dc.device_id = d.id
        ),
        '{}'::jsonb
    ) as channel_labels
FROM devices d;

-- Step 7: Grant permissions on view
GRANT SELECT ON devices_with_channels TO authenticated;

-- Step 8: Verify the changes
SELECT 
  column_name, 
  data_type, 
  column_default 
FROM information_schema.columns 
WHERE table_name = 'device_channels' 
  AND column_name = 'channel_type';

-- You should see: channel_type | text | 'light'::text
