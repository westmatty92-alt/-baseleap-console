-- 009: build_steps.deployment — structured deployment guide per artifact step
-- (deployment guide / notes split DoD, locked July 5 2026). Run manually in the
-- Supabase SQL editor.
-- Holds the full auto-generated deployment story for the engine's artifact-carrying
-- step: { route, needs_review, changes_note, parameter_values, tiers (branding /
-- business_rules / never_touch), overrides, spec_extras }. Renders as the READ-ONLY
-- collapsed "Deployment guide" section; the notes column now holds ONLY
-- operator-typed text on new plans. Historical rows keep their old notes dump and
-- simply have deployment = NULL (decision (a): never rewrite history).
-- Needed because formulated engines have no engine_catalog row to render from live.

ALTER TABLE build_steps ADD COLUMN IF NOT EXISTS deployment JSONB;
