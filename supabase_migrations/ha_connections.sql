-- Home Assistant connections table
-- Stores HA instance connection details per user
-- Created: 2026-03-29 by Commander (hbot-lead)

CREATE TABLE IF NOT EXISTS ha_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  instance_name TEXT NOT NULL DEFAULT 'Home',
  base_url TEXT NOT NULL, -- e.g. http://192.168.1.100:8123
  access_token TEXT, -- long-lived access token (encrypted at rest by Supabase)
  refresh_token TEXT, -- OAuth2 refresh token
  token_expires_at TIMESTAMPTZ,
  ha_version TEXT, -- discovered HA version
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One active connection per user (for now)
CREATE UNIQUE INDEX ha_connections_user_active_idx
  ON ha_connections(user_id) WHERE is_active = true;

-- RLS: users can only see/modify their own connections
ALTER TABLE ha_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own HA connections"
  ON ha_connections FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own HA connections"
  ON ha_connections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own HA connections"
  ON ha_connections FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own HA connections"
  ON ha_connections FOR DELETE
  USING (auth.uid() = user_id);
