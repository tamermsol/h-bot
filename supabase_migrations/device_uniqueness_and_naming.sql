-- =====================================================
-- Device Uniqueness and Persistent Naming Migration
-- Implements physical device uniqueness and persistent custom names
-- =====================================================

-- First, let's backup the existing devices table structure
-- (This migration assumes the current devices table exists)

-- Create new devices table for physical device uniqueness
CREATE TABLE IF NOT EXISTS devices_new (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    topic_base TEXT NOT NULL, -- e.g., hbot_5067A0
    mac_address TEXT, -- normalized (uppercase, no colons)
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT '',
    name_is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    channels INT NOT NULL,
    home_id UUID NULL, -- current placement
    room_id UUID NULL, -- current placement
    device_type TEXT NOT NULL DEFAULT 'relay',
    matter_type TEXT,
    meta_json JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Uniqueness constraints
    CONSTRAINT unique_topic_base UNIQUE (topic_base),
    CONSTRAINT unique_mac_address UNIQUE (mac_address)
);

-- Create device_channels table for channel naming
CREATE TABLE IF NOT EXISTS device_channels (
    device_id UUID NOT NULL REFERENCES devices_new(id) ON DELETE CASCADE,
    channel_no INT NOT NULL,
    label TEXT NOT NULL,
    label_is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Uniqueness constraint
    CONSTRAINT unique_device_channel UNIQUE (device_id, channel_no),
    
    -- Check constraint for valid channel numbers
    CONSTRAINT valid_channel_no CHECK (channel_no > 0 AND channel_no <= 32)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS devices_new_owner_user_id_idx ON devices_new(owner_user_id);
CREATE INDEX IF NOT EXISTS devices_new_home_id_idx ON devices_new(home_id);
CREATE INDEX IF NOT EXISTS devices_new_room_id_idx ON devices_new(room_id);
CREATE INDEX IF NOT EXISTS devices_new_topic_base_idx ON devices_new(topic_base);
CREATE INDEX IF NOT EXISTS devices_new_mac_address_idx ON devices_new(mac_address);

CREATE INDEX IF NOT EXISTS device_channels_device_id_idx ON device_channels(device_id);
CREATE INDEX IF NOT EXISTS device_channels_device_id_channel_no_idx ON device_channels(device_id, channel_no);

-- Enable Row Level Security
ALTER TABLE devices_new ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_channels ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for devices_new
CREATE POLICY "Users can view their own devices" ON devices_new
    FOR SELECT USING (auth.uid() = owner_user_id);

CREATE POLICY "Users can insert their own devices" ON devices_new
    FOR INSERT WITH CHECK (auth.uid() = owner_user_id);

CREATE POLICY "Users can update their own devices" ON devices_new
    FOR UPDATE USING (auth.uid() = owner_user_id);

CREATE POLICY "Users can delete their own devices" ON devices_new
    FOR DELETE USING (auth.uid() = owner_user_id);

-- Create RLS policies for device_channels
CREATE POLICY "Users can view channels of their devices" ON device_channels
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM devices_new d 
            WHERE d.id = device_channels.device_id 
            AND d.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert channels for their devices" ON device_channels
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM devices_new d 
            WHERE d.id = device_channels.device_id 
            AND d.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update channels of their devices" ON device_channels
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM devices_new d 
            WHERE d.id = device_channels.device_id 
            AND d.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete channels of their devices" ON device_channels
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM devices_new d 
            WHERE d.id = device_channels.device_id 
            AND d.owner_user_id = auth.uid()
        )
    );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_devices_new_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_device_channels_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_devices_new_updated_at_trigger
    BEFORE UPDATE ON devices_new
    FOR EACH ROW
    EXECUTE FUNCTION update_devices_new_updated_at();

CREATE TRIGGER update_device_channels_updated_at_trigger
    BEFORE UPDATE ON device_channels
    FOR EACH ROW
    EXECUTE FUNCTION update_device_channels_updated_at();

-- Function to normalize MAC address (uppercase, no delimiters)
CREATE OR REPLACE FUNCTION normalize_mac_address(mac_input TEXT)
RETURNS TEXT AS $$
BEGIN
    IF mac_input IS NULL OR mac_input = '' THEN
        RETURN NULL;
    END IF;
    
    -- Remove all non-alphanumeric characters and convert to uppercase
    RETURN UPPER(REGEXP_REPLACE(mac_input, '[^A-Fa-f0-9]', '', 'g'));
END;
$$ LANGUAGE plpgsql;

-- Function to normalize topic base (consistent casing)
CREATE OR REPLACE FUNCTION normalize_topic_base(topic_input TEXT)
RETURNS TEXT AS $$
BEGIN
    IF topic_input IS NULL OR topic_input = '' THEN
        RETURN NULL;
    END IF;

    -- Convert to lowercase for consistency
    RETURN LOWER(TRIM(topic_input));
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- RPC Functions for Device Management
-- =====================================================

-- Function to claim a device (handles uniqueness and ownership)
CREATE OR REPLACE FUNCTION claim_device(
    topic_base_input TEXT,
    mac_input TEXT,
    channels_input INT,
    default_name_input TEXT,
    home_id_input UUID,
    room_id_input UUID DEFAULT NULL,
    device_type_input TEXT DEFAULT 'relay',
    matter_type_input TEXT DEFAULT NULL,
    meta_json_input JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    normalized_topic TEXT;
    normalized_mac TEXT;
    current_user_id UUID;
    existing_device_id UUID;
    new_device_id UUID;
    i INT;
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Normalize inputs
    normalized_topic := normalize_topic_base(topic_base_input);
    normalized_mac := normalize_mac_address(mac_input);

    -- Validate inputs
    IF normalized_topic IS NULL OR normalized_topic = '' THEN
        RAISE EXCEPTION 'Topic base is required';
    END IF;

    IF channels_input <= 0 OR channels_input > 32 THEN
        RAISE EXCEPTION 'Invalid channel count: %', channels_input;
    END IF;

    -- Check if device already exists with same topic_base or mac_address
    SELECT id, owner_user_id INTO existing_device_id, current_user_id
    FROM devices_new
    WHERE topic_base = normalized_topic
       OR (mac_address IS NOT NULL AND mac_address = normalized_mac);

    IF existing_device_id IS NOT NULL THEN
        -- Device exists, check ownership
        IF current_user_id != auth.uid() THEN
            RAISE EXCEPTION 'This device is already linked to another account';
        END IF;

        -- Device belongs to current user, update placement and return existing ID
        UPDATE devices_new
        SET home_id = home_id_input,
            room_id = room_id_input,
            channels = channels_input,
            updated_at = NOW()
        WHERE id = existing_device_id;

        RETURN existing_device_id;
    END IF;

    -- Device doesn't exist, create new one
    INSERT INTO devices_new (
        topic_base,
        mac_address,
        owner_user_id,
        display_name,
        name_is_custom,
        channels,
        home_id,
        room_id,
        device_type,
        matter_type,
        meta_json
    ) VALUES (
        normalized_topic,
        normalized_mac,
        auth.uid(),
        COALESCE(default_name_input, 'Smart Device'),
        FALSE,
        channels_input,
        home_id_input,
        room_id_input,
        device_type_input,
        matter_type_input,
        meta_json_input
    ) RETURNING id INTO new_device_id;

    -- Create default channel labels
    FOR i IN 1..channels_input LOOP
        INSERT INTO device_channels (device_id, channel_no, label, label_is_custom)
        VALUES (new_device_id, i, 'Channel ' || i, FALSE);
    END LOOP;

    RETURN new_device_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to rename a device
CREATE OR REPLACE FUNCTION rename_device(
    device_id_input UUID,
    name_input TEXT
)
RETURNS VOID AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate input
    IF name_input IS NULL OR TRIM(name_input) = '' THEN
        RAISE EXCEPTION 'Device name cannot be empty';
    END IF;

    -- Update device name (RLS will ensure user owns the device)
    UPDATE devices_new
    SET display_name = TRIM(name_input),
        name_is_custom = TRUE,
        updated_at = NOW()
    WHERE id = device_id_input
      AND owner_user_id = current_user_id;

    -- Check if update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device not found or access denied';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to rename a channel
CREATE OR REPLACE FUNCTION rename_channel(
    device_id_input UUID,
    channel_no_input INT,
    label_input TEXT
)
RETURNS VOID AS $$
DECLARE
    current_user_id UUID;
    device_owner_id UUID;
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate input
    IF label_input IS NULL OR TRIM(label_input) = '' THEN
        RAISE EXCEPTION 'Channel label cannot be empty';
    END IF;

    IF channel_no_input <= 0 OR channel_no_input > 32 THEN
        RAISE EXCEPTION 'Invalid channel number: %', channel_no_input;
    END IF;

    -- Check device ownership
    SELECT owner_user_id INTO device_owner_id
    FROM devices_new
    WHERE id = device_id_input;

    IF device_owner_id IS NULL THEN
        RAISE EXCEPTION 'Device not found';
    END IF;

    IF device_owner_id != current_user_id THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    -- Upsert channel label
    INSERT INTO device_channels (device_id, channel_no, label, label_is_custom)
    VALUES (device_id_input, channel_no_input, TRIM(label_input), TRUE)
    ON CONFLICT (device_id, channel_no)
    DO UPDATE SET
        label = TRIM(label_input),
        label_is_custom = TRUE,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Data Migration and Cleanup Functions
-- =====================================================

-- Function to migrate existing devices to new schema
-- This should be run after the new tables are created
CREATE OR REPLACE FUNCTION migrate_existing_devices()
RETURNS TEXT AS $$
DECLARE
    device_record RECORD;
    migrated_count INT := 0;
    error_count INT := 0;
    result_text TEXT;
BEGIN
    -- Check if old devices table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'devices') THEN
        RETURN 'No existing devices table found - migration not needed';
    END IF;

    -- Migrate devices from old table to new table
    FOR device_record IN
        SELECT
            d.*,
            h.owner_id as home_owner_id
        FROM devices d
        LEFT JOIN homes h ON d.home_id = h.id
        ORDER BY d.created_at
    LOOP
        BEGIN
            -- Try to insert into new devices table
            INSERT INTO devices_new (
                topic_base,
                mac_address,
                owner_user_id,
                display_name,
                name_is_custom,
                channels,
                home_id,
                room_id,
                device_type,
                matter_type,
                meta_json,
                created_at,
                updated_at
            ) VALUES (
                normalize_topic_base(device_record.tasmota_topic_base),
                NULL, -- MAC address not available in old schema
                device_record.home_owner_id,
                device_record.name,
                TRUE, -- Assume existing names are custom
                device_record.channels,
                device_record.home_id,
                device_record.room_id,
                device_record.device_type,
                device_record.matter_type,
                device_record.meta_json,
                device_record.created_at,
                device_record.updated_at
            );

            migrated_count := migrated_count + 1;

        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            -- Log error but continue migration
            RAISE NOTICE 'Failed to migrate device %: %', device_record.id, SQLERRM;
        END;
    END LOOP;

    result_text := format('Migration completed: %s devices migrated, %s errors',
                         migrated_count, error_count);

    RETURN result_text;
END;
$$ LANGUAGE plpgsql;

-- Function to get device with channels (for API compatibility)
CREATE OR REPLACE FUNCTION get_device_with_channels(device_id_input UUID)
RETURNS TABLE (
    id UUID,
    topic_base TEXT,
    mac_address TEXT,
    owner_user_id UUID,
    display_name TEXT,
    name_is_custom BOOLEAN,
    channels INT,
    home_id UUID,
    room_id UUID,
    device_type TEXT,
    matter_type TEXT,
    meta_json JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    channel_labels JSONB
) AS $$
BEGIN
    RETURN QUERY
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
        d.created_at,
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
    FROM devices_new d
    WHERE d.id = device_id_input
      AND d.owner_user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION claim_device TO authenticated;
GRANT EXECUTE ON FUNCTION rename_device TO authenticated;
GRANT EXECUTE ON FUNCTION rename_channel TO authenticated;
GRANT EXECUTE ON FUNCTION get_device_with_channels TO authenticated;
GRANT EXECUTE ON FUNCTION migrate_existing_devices TO service_role;

-- Create view for backward compatibility (optional)
CREATE OR REPLACE VIEW devices_with_channels AS
SELECT
    d.id,
    d.topic_base as tasmota_topic_base,
    d.mac_address,
    d.owner_user_id,
    d.display_name as name,
    d.name_is_custom,
    d.channels,
    d.home_id,
    d.room_id,
    d.device_type,
    d.matter_type,
    d.meta_json,
    d.created_at,
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
FROM devices_new d;

-- Enable RLS on the view
ALTER VIEW devices_with_channels SET (security_barrier = true);

-- Comment explaining the migration strategy
COMMENT ON TABLE devices_new IS 'New devices table with physical device uniqueness and persistent naming. Replaces the old devices table.';
COMMENT ON TABLE device_channels IS 'Channel-specific labels and customization settings for devices.';
COMMENT ON FUNCTION claim_device IS 'Claims a physical device for a user, enforcing uniqueness constraints.';
COMMENT ON FUNCTION rename_device IS 'Renames a device with persistent storage.';
COMMENT ON FUNCTION rename_channel IS 'Renames a device channel with persistent storage.';
