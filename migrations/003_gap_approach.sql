ALTER TABLE gaps ADD COLUMN IF NOT EXISTS approach TEXT;
-- values: 'build' | 'integrate' | 'replace' (nullable until the Automation Agent sets it)
