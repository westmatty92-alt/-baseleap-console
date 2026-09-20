-- 016: skills — runtime copies of the repo's authored SKILL.md files.
-- Run manually in the Supabase SQL editor. Table count moves twelve → thirteen.
--
-- WHY THIS TABLE EXISTS. The Audit prompt must load audit-discovery,
-- operational-blueprint-probing and root-cause-laddering on EVERY run. Until now a
-- skill only informed whoever wrote the prompt, once, and could silently fall out of
-- sync with it — the drift Order 14 D2 exists to kill. The obvious mechanism, a
-- browser fetch of /.claude/skills/..., died with .vercelignore: those files carry the
-- GHL write matrix and the client price bands and must never be publicly served again.
-- So the runtime copy lives here, behind the same RLS that already protects everything
-- else, and needs no new secret and no new public path.
--
-- DIRECTION IS THE WHOLE CONTRACT: THE REPO IS AUTHORED, THE DB IS RUNTIME.
-- Edits are made to .claude/skills/<name>/SKILL.md, reviewed in a PR, and pushed here
-- by scripts/sync-skills.mjs. Nothing ever flows DB → repo. That is enforced two ways
-- below rather than merely documented, because a convention that only lives in a
-- comment is the kind that gets broken at 1am.
--
-- NO SEED HERE, DELIBERATELY. Seeding rows in this migration would make it a second
-- writer alongside the sync script, and two write paths to one table can disagree —
-- which is the drift this table exists to eliminate. The script performs the initial
-- load. (Two of the three skills the Audit prompt needs did not exist when this was
-- written; they arrive with D1, and the first sync picks them up with the third.)

CREATE TABLE IF NOT EXISTS skills (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The directory name under .claude/skills/, e.g. 'audit-discovery'. UNIQUE because
  -- the loader fetches BY NAME and two rows answering to one name would make which
  -- text reached the prompt a coin flip.
  name          TEXT NOT NULL UNIQUE,

  body          TEXT NOT NULL,   -- the SKILL.md content, verbatim
  source_path   TEXT NOT NULL,   -- '.claude/skills/audit-discovery/SKILL.md'

  -- sha256 of the REPO FILE at sync time. This is the tamper check: the loader
  -- recomputes sha256(body) and compares. A mismatch means body was edited in the DB
  -- rather than in the repo — i.e. the one-way rule was broken — and the loader FAILS
  -- LOUDLY rather than feeding an unreviewed skill into a client-facing prompt.
  content_hash  TEXT NOT NULL,

  synced_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE skills ENABLE ROW LEVEL SECURITY;

-- READ-ONLY TO THE APPLICATION, BY CONSTRUCTION. Every other table's policy is
-- FOR ALL with auth.uid() = operator_id. This one is deliberately different on both
-- counts:
--
--   FOR SELECT — not FOR ALL. The product has no reason to write a skill, and a
--   policy that cannot write is a stronger guarantee than a code path that chooses
--   not to. DB → repo drift therefore cannot originate from the app at all.
--
--   No operator_id. Skills are agency-wide reference content, not per-operator rows.
--   Scoping them per operator would give each operator a private copy of a shared
--   doctrine and let two operators' Audit prompts diverge silently.
DROP POLICY IF EXISTS skills_read ON skills;
CREATE POLICY skills_read ON skills
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Writes arrive only from scripts/sync-skills.mjs using the service-role key, which
-- bypasses RLS. There is intentionally no INSERT/UPDATE/DELETE policy: the absence is
-- the control.

CREATE INDEX IF NOT EXISTS skills_name_idx ON skills (name);
