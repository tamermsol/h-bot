-- Migration: Add Shutter Device Support
-- Description: Adds shutter device type, shutter_states table, and device_shutters view
-- Date: 2025-01-06

-- ============================================================================
-- 1. Add channel_count column to devices table (if not exists)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'devices' 
    AND column_name = 'channel_count'
  ) THEN
    ALTER TABLE public.devices ADD COLUMN channel_count INTEGER NOT NULL DEFAULT 1;
    COMMENT ON COLUMN public.devices.channel_count IS 'Number of channels/relays for the device';
  END IF;
END$$;

-- ============================================================================
-- 2. Add online and last_seen_at columns to devices table (if not exists)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'devices' 
    AND column_name = 'online'
  ) THEN
    ALTER TABLE public.devices ADD COLUMN online BOOLEAN NOT NULL DEFAULT false;
    COMMENT ON COLUMN public.devices.online IS 'Whether the device is currently online';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'devices' 
    AND column_name = 'last_seen_at'
  ) THEN
    ALTER TABLE public.devices ADD COLUMN last_seen_at TIMESTAMPTZ;
    COMMENT ON COLUMN public.devices.last_seen_at IS 'Last time the device was seen online';
  END IF;
END$$;

-- ============================================================================
-- 3. Create shutter_states table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shutter_states (
  device_id UUID PRIMARY KEY REFERENCES public.devices(id) ON DELETE CASCADE,
  position INTEGER CHECK (position >= 0 AND position <= 100),
  direction SMALLINT,
  target INTEGER CHECK (target >= 0 AND target <= 100),
  tilt INTEGER CHECK (tilt >= 0 AND tilt <= 100),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.shutter_states IS 'Stores current state of shutter devices';
COMMENT ON COLUMN public.shutter_states.device_id IS 'Foreign key to devices table';
COMMENT ON COLUMN public.shutter_states.position IS 'Current position (0=closed, 100=open)';
COMMENT ON COLUMN public.shutter_states.direction IS 'Movement direction (-1=closing, 0=stopped, 1=opening)';
COMMENT ON COLUMN public.shutter_states.target IS 'Target position (0-100)';
COMMENT ON COLUMN public.shutter_states.tilt IS 'Tilt angle for venetian blinds (0-100)';
COMMENT ON COLUMN public.shutter_states.updated_at IS 'Last update timestamp';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_shutter_states_updated_at ON public.shutter_states(updated_at DESC);

-- ============================================================================
-- 4. Create device_shutters view
-- ============================================================================
CREATE OR REPLACE VIEW public.device_shutters AS
SELECT 
  d.id AS device_id,
  d.display_name AS name,
  d.topic_base AS topic,
  d.online,
  d.last_seen_at,
  d.owner_user_id,
  d.home_id,
  d.room_id,
  s.position,
  s.direction,
  s.target,
  s.tilt,
  s.updated_at
FROM public.devices d
LEFT JOIN public.shutter_states s ON s.device_id = d.id
WHERE d.device_type = 'shutter' AND d.is_deleted = false;

COMMENT ON VIEW public.device_shutters IS 'View combining devices and shutter_states for shutter devices';

-- ============================================================================
-- 5. Enable Row Level Security (RLS) on shutter_states
-- ============================================================================
ALTER TABLE public.shutter_states ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own shutter states" ON public.shutter_states;
DROP POLICY IF EXISTS "Users can insert their own shutter states" ON public.shutter_states;
DROP POLICY IF EXISTS "Users can update their own shutter states" ON public.shutter_states;
DROP POLICY IF EXISTS "Users can delete their own shutter states" ON public.shutter_states;
DROP POLICY IF EXISTS "Service role can manage all shutter states" ON public.shutter_states;

-- Create RLS policies for shutter_states
CREATE POLICY "Users can view their own shutter states"
  ON public.shutter_states
  FOR SELECT
  USING (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own shutter states"
  ON public.shutter_states
  FOR INSERT
  WITH CHECK (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own shutter states"
  ON public.shutter_states
  FOR UPDATE
  USING (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own shutter states"
  ON public.shutter_states
  FOR DELETE
  USING (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

-- Service role bypass (for agent/backend operations)
CREATE POLICY "Service role can manage all shutter states"
  ON public.shutter_states
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role')
  WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- 6. Create helper function to upsert shutter state
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upsert_shutter_state(
  p_device_id UUID,
  p_position INTEGER DEFAULT NULL,
  p_direction SMALLINT DEFAULT NULL,
  p_target INTEGER DEFAULT NULL,
  p_tilt INTEGER DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.shutter_states (
    device_id,
    position,
    direction,
    target,
    tilt,
    updated_at
  )
  VALUES (
    p_device_id,
    p_position,
    p_direction,
    p_target,
    p_tilt,
    now()
  )
  ON CONFLICT (device_id) DO UPDATE SET
    position = COALESCE(EXCLUDED.position, shutter_states.position),
    direction = COALESCE(EXCLUDED.direction, shutter_states.direction),
    target = COALESCE(EXCLUDED.target, shutter_states.target),
    tilt = COALESCE(EXCLUDED.tilt, shutter_states.tilt),
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION public.upsert_shutter_state IS 'Upserts shutter state for a device (idempotent)';

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.upsert_shutter_state TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_shutter_state TO service_role;

-- ============================================================================
-- 7. Create helper function to mark device online
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_device_online(
  p_device_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.devices
  SET 
    online = true,
    last_seen_at = now(),
    updated_at = now()
  WHERE id = p_device_id;
END;
$$;

COMMENT ON FUNCTION public.mark_device_online IS 'Marks a device as online and updates last_seen_at';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.mark_device_online TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_device_online TO service_role;

-- ============================================================================
-- 8. Create helper function to reclassify device as shutter
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reclassify_as_shutter(
  p_topic_base TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_device_id UUID;
BEGIN
  UPDATE public.devices
  SET 
    device_type = 'shutter',
    channel_count = 1,
    updated_at = now()
  WHERE topic_base = p_topic_base
  RETURNING id INTO v_device_id;
  
  RETURN v_device_id;
END;
$$;

COMMENT ON FUNCTION public.reclassify_as_shutter IS 'Reclassifies a device as shutter type (idempotent)';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.reclassify_as_shutter TO authenticated;
GRANT EXECUTE ON FUNCTION public.reclassify_as_shutter TO service_role;

-- ============================================================================
-- 9. Add indexes for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_devices_device_type ON public.devices(device_type) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_devices_topic_base ON public.devices(topic_base) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_devices_online ON public.devices(online) WHERE is_deleted = false;

-- ============================================================================
-- 10. Grant permissions on view
-- ============================================================================
GRANT SELECT ON public.device_shutters TO authenticated;
GRANT SELECT ON public.device_shutters TO service_role;

-- ============================================================================
-- Migration complete
-- ============================================================================

