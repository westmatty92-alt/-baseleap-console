# CLAUDE.md — Baseleap Console

This file tells Claude Code how to work in this repo. Read it fully before any task.
**Source-of-truth docs live IN THIS REPO:** read `MASTER_BUILD_GUIDE.md` for the build sequence and `REFERENCES.md` for reference material before starting a module. (The canonical spec also lives in the Notion page "Baseleap Console — Build Spec & Data Contracts", but the in-repo guides are what you read directly.) When a data contract changes, update the in-repo guide in the same session.

---

## WHAT THIS IS
The Baseleap Console — an internal agency tool Baseleap uses to win and onboard clients. A single-file HTML app (`index.html`) + a Vercel serverless AI proxy (`api/ai.js`), backed by Supabase (RLS on every table).
- Internal only. Not resold, not embedded in client GHL sub-accounts. Separate from Pulse (a client-facing product) and from the future master CRM.
- Houses a client-acquisition suite behind a business-switcher dropdown. One client = one row in the `clients` table.
- Five modules: Client Research, AI Audit Assistant, Automation Agent, Gap Report Builder, Proposal Generator. (Client Research is planned but not yet on the near-term roadmap below.)

## CURRENT BUILD TARGET
- Built: Console shell (auth + business-switcher + state-reset), AI proxy, Module 1 Audit Assistant, Module 2 Automation Agent Phase A (feasibility gate).
- Next: the GHL Capabilities reference distilled into two agent skills (automation + setup) + the native-vs-external boundary map → then build-planner (Phase C) + Setup Agent → Proposal Generator + scope gate.

---

## ARCHITECTURE RULES (non-negotiable)
- Single `index.html` — no separate module files. Modules are tabs/sections inside it.
- All Claude calls go through the `ai()` wrapper → `/api/ai`. NEVER a raw fetch to api.anthropic.com (CORS + key leak).
- Supabase RLS on every table. Every INSERT stamps `operator_id: S.user.id`. An UPDATE to an existing row does NOT re-stamp operator_id (RLS already covers it).
- New per-client state goes in `resetClientState()` (via `freshAudit()` etc.) so nothing bleeds between clients on switch.
- Modal backgrounds: hardcoded hex, never CSS vars (vars inherit transparency).
- Keep functions short. No monolithic mega-functions (the openAdView SyntaxError trap).
- Defensive JSON parse on all AI output — strip ```json fences, try/catch, and validate the response SHAPE, not just that it's valid JSON.
- Schema changes run MANUALLY in the Supabase SQL editor (GitHub is not wired to Supabase). Migrations live in `/migrations`. Use `ADD COLUMN IF NOT EXISTS`.
- Verify a column exists in the live DB before writing to it — never trust the docs alone; check the actual schema.
- Every Supabase write the UI depends on must `.select()` and verify the returned row. A bare `.update()` reports false success on a 0-row write — always chain `.select().single()` and re-render from the returned row.

## GIT / DEPLOY DISCIPLINE
- Ask before `git push`. Do not push without explicit approval.
- Verify a commit reached `origin/main` before trusting a Vercel redeploy. A push that never happened makes Vercel faithfully redeploy old code while appearing successful.
- Env var `ANTHROPIC_API_KEY` must be set on Vercel Production (not Preview-only); redeploy after changing env vars.
- Repo has a leading hyphen: `-baseleap-console`. Use `./` in shell paths.

## BRAND TOKENS (use these for all UI — no other colors)
- Midnight `#0D1F2D` (primary dark) · Volt `#00D4A0` (accent) · Canvas `#F4F5F0` (light bg) · Depth `#1A1A2E` (text/dark) · Run `#00A878` (secondary green)
- Headline font: Garet ExtraBold.
- Tokens are defined in `:root` in `index.html` — use those, don't hardcode hex outside it (modal backgrounds are the one documented exception above).

---

## DATA CONTRACTS (see MASTER_BUILD_GUIDE.md / REFERENCES.md for full detail)
- `clients` — one row per client/prospect. `current_stack` (JSONB) written by the Audit Assistant Stack tab (UPDATE), read by the Automation Agent. Archive with status; don't hard-delete.
- `gaps` — one row per atomic gap. Lifecycle: Audit Assistant writes `pending` (title/problem/cost/severity/category) → Automation Agent writes `feasible/mechanism/estimated_hours/approach` and flips to `validated`. Never let the Audit Assistant set `validated`.
- `audit_sessions` — one row per audit (transcript/summary/status); gaps FK via `audit_session_id`.
- `build_plans` — parent record per engagement (post-agreement only). Build steps in dependency order, status `queued → building → testing → done`. Supports cross-agent step dependencies.

## THE GAP LIFECYCLE (core contract)
A gap is the atomic unit that gets built, feasibility-checked, and priced (~1:1 to a sellable GHL automation). Audit Assistant identifies → Automation Agent qualifies → Gap Report reads only `validated`. Selection state (`proposed|accepted|declined`) drives BOTH the proposal and the build plan — one selection, two projections, always in sync.

## SCHEMA
Seven tables, RLS on all: `clients`, `audit_sessions`, `gaps`, `build_plans`, `gap_reports`, `proposals`, `client_files`. Schema changes are incremental — see `/migrations` (`ADD COLUMN IF NOT EXISTS`), run manually in the Supabase SQL editor.

## REASONING SKILLS
Each agent reads its skills in-context from `.claude/skills/<name>/SKILL.md` (curated/lean, not a dump). Build a skill alongside its agent, not up-front.

---

## WORKFLOW
1. Read this file, `REFERENCES.md`, and `MASTER_BUILD_GUIDE.md` (build sequence) + the relevant module section before starting.
2. Read the Notion track plan and the highest-priority incomplete item.
3. Explore the existing `index.html` for the pattern before adding a module — this repo has strong patterns; follow them.
4. Describe your approach and wait for approval before implementing (plan mode).
5. Build → test → verify Supabase writes returned rows → ask before pushing.
6. If a data contract changed, update the in-repo guide in the same session.
