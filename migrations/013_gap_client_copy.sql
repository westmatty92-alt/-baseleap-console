-- 013: client-facing synthesized Gap Report copy (two-phase).
-- Run manually in the Supabase SQL editor. Additive-only (ADD COLUMN IF NOT EXISTS).
-- gaps.problem / gaps.cost REMAIN the raw internal transcript (audit truth); this is the
-- client-safe synthesized PROJECTION shown in the Gap Report. Generated in two phases:
--   Phase 1 (Conclusion + Cost) at validate — grounded in the raw transcript.
--   Phase 2 (Solution + Savings) once grounding exists — catalog spec immediately for a
--            matched engine; a formulate gap's build step at build-save.
-- Table count unchanged (columns only). See CLAUDE.md → DATA CONTRACTS → gaps.

ALTER TABLE gaps ADD COLUMN IF NOT EXISTS client_copy JSONB;
-- client_copy shape:
-- {
--   problem, cost,                  -- phase 1 (present once generated)
--   solution, savings,              -- phase 2 (NULL until grounded; NULL = interim for formulate)
--   route: 'cataloged' | 'formulated',
--   phase: 'conclusion' | 'complete',   -- 'conclusion' = solution/savings still pending a build
--   generated_at, solution_at       -- phase-1 iso time; phase-2 iso time (NULL until complete)
-- }
-- client_copy NULL entirely = not generated yet → Gap Report shows the ungenerated affordance.
-- ONLY the synthesized sections are ever shown to a client; raw problem/cost never verbatim.

ALTER TABLE gaps ADD COLUMN IF NOT EXISTS client_copy_fingerprint TEXT;
-- Hash of the SOURCE inputs (raw problem+cost+matched_engine+mechanism+approach). Its OWN column
-- (not inside client_copy) so the staleness check is a cheap compare, not a JSONB parse:
--   client_copy_fingerprint <> fingerprint(gap) → source changed → copy stale → regenerate.
-- Progression conclusion→complete is driven by the build-save event, NOT this fingerprint.
