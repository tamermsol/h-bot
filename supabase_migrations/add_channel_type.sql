-- =====================================================
-- Add Channel Type Support (Light or Switch)
-- Allows each relay channel to be configured as light or switch
-- =====================================================

-- Add channel_type column to device_channels table
ALTER TABLE device_channels 
ADD COLUMN IF NOT EXISTS channel_type TEXT NOT NULL DEFAULT 'light';

-- Add check constraint to ensure valid channel types
ALTER TABLE device_channels
DROP CONSTRAINT IF EXISTS check_channel_type;

ALTER TABLE device_channels
ADD CONSTRAINT check_channel_type 
CHECK (channel_type IN ('light', 'switch'));

-- Create index for performance
CREATE INDEX IF NOT EXISTS device_channels_channel_type_idx 
ON device_channels(channel_type);

-- Update the rename_channel function to preserve channel_type
CREATE OR REPLACE FUNCTION rename_channel(
  p_device_id UUID,
  p_channel_no INT,
  p_label TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner UUID := auth.uid();
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_label IS NULL OR trim(p_label) = '' THEN
    RAISE EXCEPTION 'channel label cannot be empty';
  END IF;

  -- Check device ownership
  IF NOT EXISTS (SELECT 1 FROM devices WHERE id = p_device_id AND owner_user_id = v_owner) THEN
    RAISE EXCEPTION 'device not found or access denied';
  END IF;

  -- Upsert channel label (preserve channel_type)
  INSERT INTO device_channels (device_id, channel_no, label, label_is_custom, channel_type)
  VALUES (p_device_id, p_channel_no, trim(p_label), true, 'light')
  ON CONFLICT (device_id, channel_no)
  DO UPDATE SET
      label = trim(p_label),
      label_is_custom = true,
      updated_at = now();
END $$;

-- Create new function to update channel type
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_channel_type TO authenticated;

-- Update the devices_with_channels view to include channel_type
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

-- Grant permissions
GRANT SELECT ON devices_with_channels TO authenticated;

-- Add comment
COMMENT ON COLUMN device_channels.channel_type IS 'Type of channel: light or switch. Determines the icon and behavior in the UI.';
