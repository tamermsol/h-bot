-- Home Assistant entities table
-- Maps HA entities to H-Bot devices for display in app and panel
-- Created: 2026-03-29 by Commander (hbot-lead)

-- Add source_type to devices table
ALTER TABLE devices ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'tasmota';

-- Home Assistant entities (imported from HA)
CREATE TABLE IF NOT EXISTS ha_entities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id UUID NOT NULL REFERENCES ha_connections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_id TEXT NOT NULL, -- e.g. "light.living_room"
  domain TEXT NOT NULL, -- e.g. "light", "switch", "climate", "cover", "sensor"
  friendly_name TEXT,
  ha_device_id TEXT, -- HA device registry ID
  ha_area_id TEXT, -- HA area registry ID
  ha_area_name TEXT, -- cached area name
  home_id UUID REFERENCES homes(id) ON DELETE SET NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  is_visible BOOLEAN NOT NULL DEFAULT true, -- user can hide entities
  icon TEXT, -- MDI icon string
  device_class TEXT, -- HA device_class (temperature, humidity, etc.)
  supported_features INT DEFAULT 0,
  state_json JSONB, -- last known state + attributes
  last_state_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique entity per connection
CREATE UNIQUE INDEX ha_entities_connection_entity_idx
  ON ha_entities(connection_id, entity_id);

-- Fast lookups
CREATE INDEX ha_entities_user_idx ON ha_entities(user_id);
CREATE INDEX ha_entities_domain_idx ON ha_entities(domain);
CREATE INDEX ha_entities_home_idx ON ha_entities(home_id);
CREATE INDEX ha_entities_room_idx ON ha_entities(room_id);

-- RLS
ALTER TABLE ha_entities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own HA entities"
  ON ha_entities FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own HA entities"
  ON ha_entities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own HA entities"
  ON ha_entities FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own HA entities"
  ON ha_entities FOR DELETE
  USING (auth.uid() = user_id);
