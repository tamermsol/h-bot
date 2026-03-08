-- Fix devices_with_channels view to include all necessary columns
-- This ensures the view includes online status, channel_count, and other missing fields

-- Drop existing view
DROP VIEW IF EXISTS devices_with_channels CASCADE;

-- Create updated view with all necessary columns
CREATE OR REPLACE VIEW devices_with_channels AS
SELECT
    d.id,
    d.topic_base as tasmota_topic_base,  -- Map to expected field name
    d.topic_base,                        -- Keep original for new code
    d.mac_address,
    d.owner_user_id,
    d.display_name as name,              -- Map to expected field name
    d.display_name,                      -- Keep original for new code
    d.name_is_custom,
    d.channels,
    d.channel_count,                     -- Add channel_count
    d.home_id,
    d.room_id,
    d.device_type,
    d.matter_type,
    d.meta_json,
    d.inserted_at as created_at,         -- Map to expected field name
    d.inserted_at,                       -- Keep original for new code
    d.updated_at,
    d.online,                            -- Add online status
    d.last_seen_at,                      -- Add last seen timestamp
    d.is_deleted,                        -- Add deletion flag
    d.deleted_at,                        -- Add deletion timestamp
    COALESCE(
        (
            SELECT jsonb_object_agg(dc.channel_no::text,
                jsonb_build_object(
                    'label', dc.label,
                    'is_custom', dc.label_is_custom,
                    'channel_type', dc.channel_type
                )
            )
            FROM device_channels dc
            WHERE dc.device_id = d.id
        ),
        '{}'::jsonb
    ) as channel_labels
FROM devices d
WHERE d.is_deleted = false;  -- Only show non-deleted devices

-- Grant permissions
GRANT SELECT ON devices_with_channels TO authenticated;

-- Add comment explaining the view
COMMENT ON VIEW devices_with_channels IS 'Complete device view with all columns including online status, channel_count, and channel labels. Filters out deleted devices.';
