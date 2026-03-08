-- Migration: Add Background Images Support
-- Description: Adds background_image_url to rooms and homes tables
-- Date: 2025-02-22

-- ============================================================================
-- 1. Add background_image_url column to rooms table
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'rooms' 
    AND column_name = 'background_image_url'
  ) THEN
    ALTER TABLE public.rooms ADD COLUMN background_image_url TEXT;
    COMMENT ON COLUMN public.rooms.background_image_url IS 'URL or path to the background image for the room';
  END IF;
END$$;

-- ============================================================================
-- 2. Add background_image_url column to homes table
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'homes' 
    AND column_name = 'background_image_url'
  ) THEN
    ALTER TABLE public.homes ADD COLUMN background_image_url TEXT;
    COMMENT ON COLUMN public.homes.background_image_url IS 'URL or path to the background image for the home dashboard';
  END IF;
END$$;

-- ============================================================================
-- 3. Create storage bucket for background images (if not exists)
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('background-images', 'background-images', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 4. Set up storage policies for background images
-- ============================================================================

-- Allow authenticated users to upload their own background images
CREATE POLICY IF NOT EXISTS "Users can upload background images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'background-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own background images
CREATE POLICY IF NOT EXISTS "Users can update their background images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'background-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own background images
CREATE POLICY IF NOT EXISTS "Users can delete their background images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'background-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow public read access to background images
CREATE POLICY IF NOT EXISTS "Public can view background images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'background-images');
