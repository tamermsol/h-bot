-- =====================================================
-- Fix Device Creation Flow + DB Rules
-- Addresses RLS issues, unique constraints, and error handling
-- =====================================================

-- Drop existing tables if they exist (for clean reset)
DROP TABLE IF EXISTS device_channels CASCADE;
DROP TABLE IF EXISTS devices CASCADE;

-- Create devices table with proper structure
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_base TEXT NOT NULL,
  mac_address TEXT,
  topic_key TEXT GENERATED ALWAYS AS (lower(topic_base)) STORED,
  mac_key TEXT GENERATED ALWAYS AS (replace(upper(coalesce(mac_address,'')), ':','')) STORED,
  owner_user_id UUID NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  name_is_custom BOOLEAN NOT NULL DEFAULT false,
  channels INT NOT NULL,
  home_id UUID NULL,
  room_id UUID NULL,
  device_type TEXT NOT NULL DEFAULT 'relay',
  matter_type TEXT,
  meta_json JSONB,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create unique indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_devices_topic ON devices(topic_key);
CREATE UNIQUE INDEX IF NOT EXISTS uq_devices_mac ON devices(mac_key) WHERE mac_key <> '';

-- Create device_channels table
CREATE TABLE IF NOT EXISTS device_channels (
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  channel_no INT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  label_is_custom BOOLEAN NOT NULL DEFAULT false,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, channel_no)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS devices_owner_user_id_idx ON devices(owner_user_id);
CREATE INDEX IF NOT EXISTS devices_home_id_idx ON devices(home_id);
CREATE INDEX IF NOT EXISTS devices_topic_base_idx ON devices(topic_base);
CREATE INDEX IF NOT EXISTS device_channels_device_id_idx ON device_channels(device_id);

-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_channels ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS p_devices_select ON devices;
DROP POLICY IF EXISTS p_devices_insert ON devices;
DROP POLICY IF EXISTS p_devices_update ON devices;
DROP POLICY IF EXISTS p_devices_delete ON devices;
DROP POLICY IF EXISTS p_channels_select ON device_channels;
DROP POLICY IF EXISTS p_channels_upsert ON device_channels;
DROP POLICY IF EXISTS p_channels_update ON device_channels;
DROP POLICY IF EXISTS p_channels_delete ON device_channels;

-- Create RLS policies for devices
CREATE POLICY p_devices_select ON devices FOR SELECT USING (owner_user_id = auth.uid());
CREATE POLICY p_devices_insert ON devices FOR INSERT WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY p_devices_update ON devices FOR UPDATE USING (owner_user_id = auth.uid());
CREATE POLICY p_devices_delete ON devices FOR DELETE USING (owner_user_id = auth.uid());

-- Create RLS policies for device_channels
CREATE POLICY p_channels_select ON device_channels FOR SELECT USING (
  EXISTS (SELECT 1 FROM devices d WHERE d.id = device_id AND d.owner_user_id = auth.uid())
);
CREATE POLICY p_channels_upsert ON device_channels FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM devices d WHERE d.id = device_id AND d.owner_user_id = auth.uid())
);
CREATE POLICY p_channels_update ON device_channels FOR UPDATE USING (
  EXISTS (SELECT 1 FROM devices d WHERE d.id = device_id AND d.owner_user_id = auth.uid())
);
CREATE POLICY p_channels_delete ON device_channels FOR DELETE USING (
  EXISTS (SELECT 1 FROM devices d WHERE d.id = device_id AND d.owner_user_id = auth.uid())
);

-- Create updated_at trigger functions
CREATE OR REPLACE FUNCTION update_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_device_channels_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS update_devices_updated_at_trigger ON devices;
DROP TRIGGER IF EXISTS update_device_channels_updated_at_trigger ON device_channels;

CREATE TRIGGER update_devices_updated_at_trigger
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_devices_updated_at();

CREATE TRIGGER update_device_channels_updated_at_trigger
    BEFORE UPDATE ON device_channels
    FOR EACH ROW
    EXECUTE FUNCTION update_device_channels_updated_at();

-- RPC: claim_device (transactional + idempotent)
CREATE OR REPLACE FUNCTION claim_device(
  p_topic_base TEXT,
  p_mac TEXT,
  p_channels INT,
  p_default_name TEXT,
  p_home_id UUID,
  p_room_id UUID
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner UUID := auth.uid();
  v_id UUID;
  v_topic_key TEXT := lower(p_topic_base);
  v_mac_key TEXT := replace(upper(coalesce(p_mac,'')), ':','');
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- If device exists with same topic or MAC
  SELECT id INTO v_id
  FROM devices
  WHERE topic_key = v_topic_key
     OR (v_mac_key <> '' AND mac_key = v_mac_key)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    -- Enforce ownership
    IF (SELECT owner_user_id FROM devices WHERE id = v_id) <> v_owner THEN
      RAISE EXCEPTION 'device already linked to another account';
    END IF;

    -- Update placement/channels if changed
    UPDATE devices
       SET home_id = coalesce(p_home_id, home_id),
           room_id = coalesce(p_room_id, room_id),
           channels = p_channels,
           updated_at = now()
     WHERE id = v_id;

  ELSE
    INSERT INTO devices (topic_base, mac_address, owner_user_id, display_name, channels, home_id, room_id)
    VALUES (p_topic_base, p_mac, v_owner, coalesce(p_default_name,''), p_channels, p_home_id, p_room_id)
    RETURNING id INTO v_id;

    -- Seed channels
    INSERT INTO device_channels(device_id, channel_no, label)
    SELECT v_id, g, 'Channel ' || g
    FROM generate_series(1, greatest(p_channels,1)) g;
  END IF;

  RETURN v_id;
END $$;

-- RPC: rename_device
CREATE OR REPLACE FUNCTION rename_device(
  p_device_id UUID,
  p_name TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner UUID := auth.uid();
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'device name cannot be empty';
  END IF;

  UPDATE devices
     SET display_name = trim(p_name),
         name_is_custom = true,
         updated_at = now()
   WHERE id = p_device_id
     AND owner_user_id = v_owner;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'device not found or access denied';
  END IF;
END $$;

-- RPC: rename_channel
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

  -- Upsert channel label
  INSERT INTO device_channels (device_id, channel_no, label, label_is_custom)
  VALUES (p_device_id, p_channel_no, trim(p_label), true)
  ON CONFLICT (device_id, channel_no)
  DO UPDATE SET
      label = trim(p_label),
      label_is_custom = true,
      updated_at = now();
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION claim_device TO authenticated;
GRANT EXECUTE ON FUNCTION rename_device TO authenticated;
GRANT EXECUTE ON FUNCTION rename_channel TO authenticated;

-- Create view for device with channels
CREATE OR REPLACE VIEW devices_with_channels AS
SELECT
    d.id,
    d.topic_base,
    d.mac_address,
    d.owner_user_id,
    d.display_name,
    d.name_is_custom,
    d.channels,
    d.home_id,
    d.room_id,
    d.device_type,
    d.matter_type,
    d.meta_json,
    d.inserted_at,
    d.updated_at,
    COALESCE(
        (
            SELECT jsonb_object_agg(dc.channel_no::text,
                jsonb_build_object(
                    'label', dc.label,
                    'is_custom', dc.label_is_custom
                )
            )
            FROM device_channels dc
            WHERE dc.device_id = d.id
        ),
        '{}'::jsonb
    ) as channel_labels
FROM devices d;

-- Enable RLS on the view
ALTER VIEW devices_with_channels SET (security_barrier = true);

-- Comments
COMMENT ON TABLE devices IS 'Devices table with physical device uniqueness and persistent naming';
COMMENT ON TABLE device_channels IS 'Channel-specific labels and customization settings';
COMMENT ON FUNCTION claim_device IS 'Claims a physical device for a user, enforcing uniqueness constraints';
COMMENT ON FUNCTION rename_device IS 'Renames a device with persistent storage';
COMMENT ON FUNCTION rename_channel IS 'Renames a device channel with persistent storage';
