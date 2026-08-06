-- 014: deployed_systems — the deployed-system ledger (Order 16 v1).
-- Run manually in the Supabase SQL editor. Table count moves eleven → twelve.
-- RLS pattern: auth.uid() = operator_id for USING and WITH CHECK (as in 005/006/010).
--
-- WHY THIS IS AN OPERATOR ASSERTION, NOT A DERIVATION: the Setup Agent can
-- mechanically create exactly five kinds (tags, fields, custom values, calendars,
-- pipelines) and workflows are NOT among them — the engines are hand-built in GHL.
-- clients.ghl_map proves an asset exists but is flat and cannot attribute it to an
-- engine; setup_runs proves a provisioning run happened but covers only those five
-- kinds. So "engine X is live for client Y" has no derivable source; a human states it.

CREATE TABLE IF NOT EXISTS deployed_systems (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id    UUID NOT NULL,
  client_id      UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,

  -- POINTERS — ON DELETE SET NULL, never CASCADE. Deleting a build_plans row cascades
  -- to build_steps; if these pointers cascaded too, deleting a plan would erase the
  -- record that its engines are live in a client's account. The snapshot below is
  -- what survives that, which is the whole reason the snapshot exists.
  build_plan_id  UUID REFERENCES build_plans(id) ON DELETE SET NULL,
  build_step_id  UUID REFERENCES build_steps(id) ON DELETE SET NULL,

  -- SNAPSHOT — copied from the engine step at assert time, never re-read from it.
  title          TEXT NOT NULL,   -- the engine step's title at deploy time
  engine_key     TEXT,            -- snapshot of build_steps.matched_engine; NULL for a formulated engine
  mode           TEXT CHECK (mode IN ('retrieve','formulate')),
  -- mode is what a future graduation pass reads: a `formulate` engine that reached a
  -- ledger entry is one designed from scratch and then actually built and shipped.

  deployed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One step can never be marked deployed twice. PARTIAL because build_step_id goes NULL
-- when a plan is deleted, and multiple orphaned snapshots must still be allowed to
-- coexist (NULLs are distinct in a plain unique index, but the partial predicate makes
-- the intent explicit rather than incidental).
CREATE UNIQUE INDEX IF NOT EXISTS deployed_systems_step_uniq
  ON deployed_systems (build_step_id) WHERE build_step_id IS NOT NULL;

-- Read path is always client-scoped (the ledger loads with the client's build plans).
CREATE INDEX IF NOT EXISTS deployed_systems_client_idx
  ON deployed_systems (client_id, deployed_at DESC);

ALTER TABLE deployed_systems ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS deployed_systems_operator ON deployed_systems;
CREATE POLICY deployed_systems_operator ON deployed_systems
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
