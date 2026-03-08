-- Create RPC function to get server UTC time
-- This ensures all clients use the same reference clock

CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'utc_now', (now() AT TIME ZONE 'utc')::text,
    'timezone', 'UTC'
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated;

-- Test the function
SELECT public.get_server_time();
-- Expected output: {"utc_now": "2024-01-01 12:00:00.123456", "timezone": "UTC"}
