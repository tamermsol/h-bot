-- Fix device view mapping for backward compatibility
-- This ensures the devices_with_channels view properly maps database columns to app expectations

-- Drop existing view
DROP VIEW IF EXISTS devices_with_channels;

-- Create updated view with proper column mapping
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
    d.home_id,
    d.room_id,
    d.device_type,
    d.matter_type,
    d.meta_json,
    d.inserted_at as created_at,         -- Map to expected field name
    d.inserted_at,                       -- Keep original for new code
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

-- Grant permissions
GRANT SELECT ON devices_with_channels TO authenticated;

-- Add comment explaining the mapping
COMMENT ON VIEW devices_with_channels IS 'Backward compatible view that maps database columns to app expectations: topic_base->tasmota_topic_base, display_name->name, inserted_at->created_at';
