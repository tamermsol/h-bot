-- Create scene_commands table for edge function to queue commands
-- Mobile app will listen to this table and execute MQTT commands

CREATE TABLE IF NOT EXISTS public.scene_commands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scene_run_id uuid REFERENCES public.scene_runs(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  topic_base text NOT NULL,
  action_type text NOT NULL, -- 'power', 'shutter', 'dimmer', etc.
  action_data jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  executed_at timestamp with time zone,
  executed boolean NOT NULL DEFAULT false,
  error_message text
);

-- Index for efficient querying of pending commands
CREATE INDEX IF NOT EXISTS idx_scene_commands_pending 
  ON public.scene_commands(executed, created_at) 
  WHERE executed = false;

-- Index for device lookup
CREATE INDEX IF NOT EXISTS idx_scene_commands_device 
  ON public.scene_commands(device_id);

-- Enable RLS
ALTER TABLE public.scene_commands ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view commands for their devices
CREATE POLICY "Users can view their scene commands"
  ON public.scene_commands
  FOR SELECT
  USING (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

-- Policy: Users can update execution status of their commands
CREATE POLICY "Users can update their scene commands"
  ON public.scene_commands
  FOR UPDATE
  USING (
    device_id IN (
      SELECT id FROM public.devices WHERE owner_user_id = auth.uid()
    )
  );

-- Policy: Service role can insert commands (for edge function)
CREATE POLICY "Service role can insert scene commands"
  ON public.scene_commands
  FOR INSERT
  WITH CHECK (true);

-- Add cleanup function to delete old executed commands (older than 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_scene_commands()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.scene_commands
  WHERE executed = true
    AND executed_at < now() - interval '7 days';
END;
$$;

-- Optional: Create a cron job to run cleanup daily
-- This requires pg_cron extension
-- SELECT cron.schedule('cleanup-scene-commands', '0 2 * * *', 'SELECT cleanup_old_scene_commands()');
