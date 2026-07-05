-- 008: Build-Plan Depth — field/tag manifest + structured node workflow per step
-- (Build-Plan Depth DoD, locked July 5 2026). Run manually in the Supabase SQL editor.
-- manifest: the step's field/tag manifest {requires_tags, creates_tags, requires_fields}
--   on the engine's artifact-carrying step and on code-injected "create tags & fields"
--   setup steps; {"tbd": true} on steps of a routed engine that has no manifest yet
--   (thin catalog engine — flag stays visible instead of silently missing setup).
-- workflow: the structured node-by-node workflow (automations array — typed nodes for
--   formulated engines, the catalog spec's automations for retrieved ones). Rendered
--   only when the step is expanded; these are the nodes the System Map will traverse.
-- engine_catalog needs no change — spec is JSONB; spec.manifest merges in via
--   updateEngineManifest() from the browser console (same pattern as spec.deployment).

ALTER TABLE build_steps ADD COLUMN IF NOT EXISTS manifest JSONB;
ALTER TABLE build_steps ADD COLUMN IF NOT EXISTS workflow JSONB;
