-- ============================================================================
-- Simple Migration: Add background_image_url columns ONLY
-- No storage bucket, no policies - just the database columns
-- ============================================================================

-- Add background_image_url to rooms table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'rooms' 
    AND column_name = 'background_image_url'
  ) THEN
    ALTER TABLE public.rooms ADD COLUMN background_image_url TEXT;
    RAISE NOTICE 'Added background_image_url column to rooms table';
  ELSE
    RAISE NOTICE 'Column background_image_url already exists in rooms table';
  END IF;
END$$;

-- Add background_image_url to homes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'homes' 
    AND column_name = 'background_image_url'
  ) THEN
    ALTER TABLE public.homes ADD COLUMN background_image_url TEXT;
    RAISE NOTICE 'Added background_image_url column to homes table';
  ELSE
    RAISE NOTICE 'Column background_image_url already exists in homes table';
  END IF;
END$$;

-- Verify the columns were added
SELECT 
  'rooms' as table_name,
  column_name,
  data_type,
  '✅ Success!' as status
FROM information_schema.columns 
WHERE table_name = 'rooms' 
AND column_name = 'background_image_url'

UNION ALL

SELECT 
  'homes' as table_name,
  column_name,
  data_type,
  '✅ Success!' as status
FROM information_schema.columns 
WHERE table_name = 'homes' 
AND column_name = 'background_image_url';

-- Expected output: 2 rows showing the columns exist
