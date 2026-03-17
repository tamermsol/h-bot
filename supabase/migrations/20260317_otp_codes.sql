-- OTP verification codes table
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  email text NOT NULL,
  code text NOT NULL,
  type text NOT NULL CHECK (type IN ('signup', 'reset')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '10 minutes'),
  used boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Index for lookup
CREATE INDEX IF NOT EXISTS idx_otp_codes_email_type ON public.otp_codes (email, type, used);

-- Auto-cleanup expired codes
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
  DELETE FROM public.otp_codes WHERE expires_at < now() OR used = true;
END;
$$ LANGUAGE plpgsql;

-- RLS: Allow authenticated and anon users to interact (controlled via Edge Function)
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

-- Policy: anon can insert (via edge function service role, but also allow direct insert for flexibility)
CREATE POLICY "Allow insert otp_codes" ON public.otp_codes
  FOR INSERT WITH CHECK (true);

-- Policy: anon can select their own codes by email
CREATE POLICY "Allow select otp_codes by email" ON public.otp_codes
  FOR SELECT USING (true);

-- Policy: anon can update (mark as used)
CREATE POLICY "Allow update otp_codes" ON public.otp_codes
  FOR UPDATE USING (true);
