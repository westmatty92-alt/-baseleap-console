ALTER TABLE gaps ADD COLUMN IF NOT EXISTS feasible BOOLEAN;
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS mechanism TEXT;
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS estimated_hours NUMERIC;
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS band TEXT;
-- band values: 'simple' | 'standard' | 'complex' (nullable until the Automation Agent sets it)
-- Idempotent safety net: feasible/mechanism/estimated_hours were documented as already
-- existing but never verified live; band is new — the pricing anchor Modules 3/4 read.
