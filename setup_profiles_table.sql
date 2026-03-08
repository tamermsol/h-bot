-- =====================================================
-- Updated Profiles Table Setup (matches your existing schema)
-- Run this in your Supabase SQL Editor
-- =====================================================

-- Ensure the profiles table exists with your current structure
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure phone_number column exists (your existing code)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number text;

-- E.164-ish format check (your existing code)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_phone_e164_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_phone_e164_check
  CHECK (phone_number IS NULL OR phone_number ~ '^\+?[1-9]\d{1,14}$');

-- Unique constraint for phone numbers (your existing code)
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_phone
  ON public.profiles (phone_number)
  WHERE phone_number IS NOT NULL;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (your existing code)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to make this re-runnable (your existing code)
DROP POLICY IF EXISTS "profiles_self_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_insert" ON public.profiles;

-- Create RLS policies (your existing code)
CREATE POLICY "profiles_self_select"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "profiles_self_update"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_self_insert"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS profiles_phone_number_idx ON public.profiles(phone_number);
CREATE INDEX IF NOT EXISTS profiles_created_at_idx ON public.profiles(created_at);

-- Grant permissions
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
