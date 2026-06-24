-- Check if CitizenshipDocUrl and SignatureUrl columns exist on Members table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'Members'
ORDER BY ordinal_position;
