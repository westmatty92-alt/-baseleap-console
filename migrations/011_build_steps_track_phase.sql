-- 011: build_steps.track + build_steps.phase — additive prep for a future
-- unified multi-track build plan (CRM + Agent + App) and PM Tracker status.
-- Run manually in the Supabase SQL editor. PURELY additive — no behavior change:
-- existing CRM-only plans backfill to track='automation' and render identically.
-- NOTE: track != the existing `agent` column. `agent` ('setup'|'automation') =
--   which sub-agent builds the step. `track` ('automation'|'agent'|'app') =
--   which product line the step belongs to. The overlap of the string
--   'automation' across both is intentional and semantically distinct; the
--   names are kept as-is (renaming working columns for a naming preference is
--   real risk, not a functional fix).

-- track: product line. DEFAULT backfills every existing row to 'automation'
-- in the same statement, so current plans are unchanged. Nullable per spec;
-- a CHECK passes NULL, so nullability and the closed vocabulary coexist.
-- Named constraint (not 005's auto-named inline CHECK) so a future change can
-- target it by name — the lesson from 007's mode-vocabulary swap.
ALTER TABLE build_steps ADD COLUMN IF NOT EXISTS track TEXT DEFAULT 'automation';
ALTER TABLE build_steps DROP CONSTRAINT IF EXISTS build_steps_track_check;
ALTER TABLE build_steps ADD CONSTRAINT build_steps_track_check
  CHECK (track IN ('automation','agent','app'));

-- phase: free-text label for the future phased view (e.g. 'CRM Core').
-- TEXT not INT: ordering already lives in `position`; the phase vocabulary is
-- undefined until the phased-display spec exists, so no CHECK, no default.
ALTER TABLE build_steps ADD COLUMN IF NOT EXISTS phase TEXT;
