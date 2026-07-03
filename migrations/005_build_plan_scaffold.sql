-- 005: Build-planner scaffold (Phase C).
-- Run manually in the Supabase SQL editor.
-- Live-schema check 2026-07-03: build_plans has id/client_id/operator_id/created_at/status
-- (status left untouched); title+summary missing. gaps missing
-- matched_engine/is_new_template/selection. No build_steps table.
-- RLS pattern confirmed 2026-07-03: auth.uid() = operator_id for USING and WITH CHECK.

-- 1. gaps — persist the Mode-1/Mode-2 routing signals + selection state
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS matched_engine TEXT;
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS is_new_template BOOLEAN;
ALTER TABLE gaps ADD COLUMN IF NOT EXISTS selection TEXT DEFAULT 'proposed';
-- selection: 'proposed' | 'accepted' | 'declined' — one selection state drives BOTH
-- the proposal and the build plan (set by Gap Report UI later; planner reads 'accepted').

-- 2. build_plans — parent record per engagement (status column already exists live; untouched)
ALTER TABLE build_plans ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE build_plans ADD COLUMN IF NOT EXISTS summary TEXT;

-- 3. build_steps — one row per step, dependency-ordered, cross-agent
CREATE TABLE IF NOT EXISTS build_steps (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  build_plan_id   UUID NOT NULL REFERENCES build_plans(id) ON DELETE CASCADE,
  operator_id     UUID NOT NULL,
  gap_id          UUID REFERENCES gaps(id),   -- null for setup/foundation steps
  agent           TEXT NOT NULL CHECK (agent IN ('setup','automation')),
  mode            TEXT CHECK (mode IN ('deploy','design')),  -- automation steps only
  matched_engine  TEXT,
  -- CLIENT-SAFE columns (the future client-portal projection reads ONLY these + status/position/agent):
  title           TEXT NOT NULL,               -- plain language, no mechanics/pricing
  -- OPERATOR-ONLY columns (never projected to the client surface):
  detail          TEXT,                        -- mechanics: trigger config, wiring, fallback path
  notes           TEXT,                        -- freeform build notes
  checklist       JSONB NOT NULL DEFAULT '[]', -- [{"text": "...", "done": false}]
  estimated_hours NUMERIC,
  -- lifecycle:
  status          TEXT NOT NULL DEFAULT 'queued'
                    CHECK (status IN ('queued','building','testing','done')),
  depends_on      UUID[] NOT NULL DEFAULT '{}',
  position        INT NOT NULL DEFAULT 0,      -- topological order (depends_on is the truth)
  completed_at    TIMESTAMPTZ,                 -- stamped on done → Phase D SOP-gen + ledger hinge
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE build_steps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS build_steps_operator ON build_steps;
CREATE POLICY build_steps_operator ON build_steps
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
