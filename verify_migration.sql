-- ============================================================================
-- Verify Migration - Check if columns exist
-- ============================================================================
-- Run this AFTER running the migration to verify it worked
-- ============================================================================

-- Check if background_image_url column exists in rooms table
SELECT 
  'rooms' as table_name,
  column_name,
  data_type,
  is_nullable,
  '✅ Column exists!' as status
FROM information_schema.columns 
WHERE table_schema = 'public'
  AND table_name = 'rooms' 
  AND column_name = 'background_image_url'

UNION ALL

-- Check if background_image_url column exists in homes table
SELECT 
  'homes' as table_name,
  column_name,
  data_type,
  is_nullable,
  '✅ Column exists!' as status
FROM information_schema.columns 
WHERE table_schema = 'public'
  AND table_name = 'homes' 
  AND column_name = 'background_image_url';

-- Expected output (2 rows):
-- table_name | column_name           | data_type | is_nullable | status
-- -----------|-----------------------|-----------|-------------|------------------
-- rooms      | background_image_url  | text      | YES         | ✅ Column exists!
-- homes      | background_image_url  | text      | YES         | ✅ Column exists!

-- If you see 0 rows, the migration didn't run successfully
-- If you see 2 rows, the migration worked! ✅
