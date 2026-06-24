-- Ensure required PostgreSQL extensions exist
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Verify extensions
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pgcrypto', 'pg_trgm', 'uuid-ossp');
