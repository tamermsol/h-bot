-- Panels table: tracks paired H-Bot wall panels
CREATE TABLE IF NOT EXISTS panels (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id       text UNIQUE NOT NULL,        -- panel hardware ID from QR
  display_name    text NOT NULL DEFAULT 'My Panel',
  broker_address  text NOT NULL,
  broker_port     int NOT NULL DEFAULT 1883,
  pairing_token   text NOT NULL,               -- SHA-256 hashed token
  owner_user_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  home_id         uuid REFERENCES homes(id) ON DELETE SET NULL,
  household_id    uuid NOT NULL,               -- stub: seeded from owner ID
  display_config  jsonb DEFAULT '{"version":1,"layout":"grid","devices":[],"scenes":[]}'::jsonb,
  paired_at       timestamptz DEFAULT now(),
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- RLS policies
ALTER TABLE panels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own panels"
  ON panels FOR SELECT
  USING (owner_user_id = auth.uid());

CREATE POLICY "Users can insert own panels"
  ON panels FOR INSERT
  WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "Users can update own panels"
  ON panels FOR UPDATE
  USING (owner_user_id = auth.uid());

CREATE POLICY "Users can delete own panels"
  ON panels FOR DELETE
  USING (owner_user_id = auth.uid());

-- Index for fast lookups
CREATE INDEX idx_panels_owner ON panels(owner_user_id);
CREATE INDEX idx_panels_device_id ON panels(device_id);
CREATE INDEX idx_panels_household ON panels(household_id);
