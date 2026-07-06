-- 010: Setup Agent — GHL API execution arm (Phase 1: manual trigger).
-- Run manually in the Supabase SQL editor.
-- Adds the per-client GHL connection + paid marker + created-item registry on
-- clients, and the setup_runs audit table (one row per execution run).
-- RLS pattern: auth.uid() = operator_id for USING and WITH CHECK (as in 005).

-- 1. clients — GHL connection + engagement state
ALTER TABLE clients ADD COLUMN IF NOT EXISTS ghl_location_id TEXT;
-- The client's GHL sub-account id. Entered once in the Setup Agent's GHL
-- settings panel; every Setup Agent API call is scoped to it.
ALTER TABLE clients ADD COLUMN IF NOT EXISTS ghl_pit_token TEXT;
-- Private Integration Token for that sub-account (Settings → Private
-- Integrations). RLS-protected; NEVER selected in the client-list query —
-- fetched only when the Setup Agent tab needs it, passed per request to
-- /api/ghl. The browser never calls GHL directly.
ALTER TABLE clients ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
-- Manual "invoice paid" marker (Phase 1). NULL = not paid. Gates the
-- Run GHL setup button. Phase 2 (own DoD) will let the invoice-paid
-- webhook stamp this instead.
ALTER TABLE clients ADD COLUMN IF NOT EXISTS ghl_map JSONB;
-- Merged name → GHL id registry, written after each setup run:
-- { "fields": {"<object>:<name>": id}, "tags": {...}, "custom_values": {...},
--   "calendars": {...} }. Functionally required: GHL sets field values by
-- fieldId, not name — this is the only durable record of the mapping.

-- 2. setup_runs — one row per Setup Agent execution (full audit trail)
CREATE TABLE IF NOT EXISTS setup_runs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id   UUID NOT NULL,
  client_id     UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  build_plan_id UUID REFERENCES build_plans(id),
  status        TEXT NOT NULL DEFAULT 'running'
                  CHECK (status IN ('running','complete','failed')),
  log           JSONB NOT NULL DEFAULT '[]',
  -- log: [{ "kind": "tag|field|custom_value|calendar", "object": "contact|opportunity",
  --         "name": "...", "action": "found|created|error", "ghl_id": "...",
  --         "error": "...", "ts": "ISO" }] — appended sequentially; fail-stop
  -- means the last entry of a failed run is the error that halted it.
  checklist     JSONB NOT NULL DEFAULT '[]',
  -- human-only checklist state: [{ "text": "...", "url": "...", "done": false }]
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at   TIMESTAMPTZ
);

ALTER TABLE setup_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS setup_runs_operator ON setup_runs;
CREATE POLICY setup_runs_operator ON setup_runs
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
