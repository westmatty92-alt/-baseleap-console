-- 006: engine_catalog — the reusable engine library the Automation Agent matches gaps against.
-- Run manually in the Supabase SQL editor.
-- New table (no live columns to verify). RLS pattern: auth.uid() = operator_id
-- for USING and WITH CHECK, same as build_steps (006 follows 005).

CREATE TABLE IF NOT EXISTS engine_catalog (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  engine_key        TEXT NOT NULL UNIQUE,        -- the match key (gaps.matched_engine points here)
  name              TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'formulated'
                      CHECK (status IN ('proven','documented','formulated')),
  category          TEXT CHECK (category IN ('setup','automation','mixed')),
  summary           TEXT,
  spec              JSONB NOT NULL DEFAULT '{}', -- full engine spec: triggers, wiring, fallback paths
  client_parameters JSONB NOT NULL DEFAULT '{}', -- per-client knobs the deploy step must fill in
  depends_on        TEXT[] NOT NULL DEFAULT '{}',-- engine_keys of prerequisite engines (not UUIDs)
  operator_id       UUID NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()  -- app stamps this on UPDATE
);

ALTER TABLE engine_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS engine_catalog_operator ON engine_catalog;
CREATE POLICY engine_catalog_operator ON engine_catalog
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
