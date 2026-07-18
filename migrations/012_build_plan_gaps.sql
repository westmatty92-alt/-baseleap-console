-- 012: per-build gap scope (folder-scoped Finalize).
-- Run manually in the Supabase SQL editor.
-- Introduces build_plan_gaps: which gaps are in THIS build, frozen at save.
-- Replaces reliance on the client-level gaps.selection for build scope.
-- gaps.selection is RETAINED-BUT-DORMANT (additive-only; a later migration can
-- retire it once nothing reads it). Table count moves seven -> eight.
-- RLS pattern: auth.uid() = operator_id for USING and WITH CHECK (as in 005/010).

CREATE TABLE IF NOT EXISTS build_plan_gaps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  build_plan_id UUID NOT NULL REFERENCES build_plans(id) ON DELETE CASCADE,
  -- CASCADE: a deleted build's scope rows go with it (like build_steps).
  gap_id        UUID NOT NULL REFERENCES gaps(id),
  -- NO cascade ON PURPOSE: this row is the build's FROZEN scope snapshot and must
  -- survive an edit to the shared client-level gap pool. The Scope-locked UI reads
  -- these joined to gaps; a since-deleted gap degrades to "gap no longer in catalog"
  -- rather than silently vanishing from the record.
  operator_id   UUID NOT NULL,
  selection     TEXT NOT NULL DEFAULT 'accepted'
                  CHECK (selection IN ('accepted','declined')),
  -- only DECIDED gaps are persisted per build; a saved build always has >=1 'accepted'.
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (build_plan_id, gap_id)
  -- one row per (build, gap). The SAME gap MAY appear in two builds (buildable across
  -- engagements) — the uniqueness is per (plan, gap), not per gap.
);

ALTER TABLE build_plan_gaps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS build_plan_gaps_operator ON build_plan_gaps;
CREATE POLICY build_plan_gaps_operator ON build_plan_gaps
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
