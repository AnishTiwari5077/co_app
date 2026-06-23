ALTER TABLE "Members" ADD COLUMN IF NOT EXISTS "CitizenshipDocUrl" TEXT;
ALTER TABLE "Members" ADD COLUMN IF NOT EXISTS "SignatureUrl" TEXT;
SELECT column_name FROM information_schema.columns 
WHERE table_name='Members' AND column_name IN ('CitizenshipDocUrl','SignatureUrl');
