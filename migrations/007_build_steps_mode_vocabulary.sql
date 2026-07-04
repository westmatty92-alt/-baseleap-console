-- 007: build_steps.mode vocabulary — deploy/design → retrieve/formulate
-- (sweep DoD, locked July 4 2026). Run manually in the Supabase SQL editor.
-- mode is the fundamental two-way split: retrieve (from catalog — drop-in OR
-- parameterize) vs formulate (designed from scratch). Drop-in vs parameterize
-- is NOT a mode: both are 'retrieve'; a parameterize step carries a
-- "changes made" note, a drop-in step doesn't.
-- Constraint name assumes the Postgres default for 005's inline CHECK; if the
-- DROP doesn't match, find the real name first:
--   SELECT conname FROM pg_constraint WHERE conrelid = 'build_steps'::regclass;
-- DROP must run before the UPDATEs — the old CHECK would reject the new values.
-- NULL stays allowed on setup steps (CHECK passes NULL).

ALTER TABLE build_steps DROP CONSTRAINT IF EXISTS build_steps_mode_check;
UPDATE build_steps SET mode = 'retrieve'  WHERE mode = 'deploy';
UPDATE build_steps SET mode = 'formulate' WHERE mode = 'design';
ALTER TABLE build_steps ADD CONSTRAINT build_steps_mode_check
  CHECK (mode IN ('retrieve','formulate'));
