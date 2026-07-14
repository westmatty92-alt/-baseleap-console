# CLAUDE.md — Baseleap Console

This file tells Claude Code how to work in this repo. Read it fully before any task.
**Source-of-truth docs live IN THIS REPO:** read `MASTER_BUILD_GUIDE.md` for the build sequence and `REFERENCES.md` for reference material before starting a module. (The canonical spec also lives in the Notion page "Baseleap Console — Build Spec & Data Contracts", but the in-repo guides are what you read directly.) When a data contract changes, update the in-repo guide in the same session.

## 🛑 THE ONE RULE
Before writing any code:
1. Read `MASTER_BUILD_GUIDE.md` and build the NEXT unbuilt item in dependency order — not whatever seems next.
2. Write a Definition of Done for that item.
3. Get Matthew's approval in plan mode.
4. Build to that spec.

**Tripwire:** if you catch yourself mid-build with undefined requirements, STOP and write the spec first.

## 🗺️ PLAN VISUALLY
For any architecture or structural decision (a data model, a new module's data flow, a pipeline, how components connect), produce a visual map as part of the plan — SVG + PNG, not just prose. Show components as nodes, the connections between them, and built-vs-planned (solid = exists, dashed = planned). Keep the source files in `docs/planning/` and embed the PNG in the relevant Notion spec. Anything with structure or multiple connected pieces earns a map.

## Lessons from session review — read every session
- When a test result gates a commit approval, write the pass/fail lines explicitly in your response text — don't rely solely on a tool-result block, which can get truncated/collapsed when relayed for review.
- When a third-party API's scope/permission name doesn't resolve after one attempt, check the provider's actual permission UI directly — don't infer the scope name from the endpoint's URL structure.
- When you notice a gap between "the API/proxy technically supports X" and "nothing in our data model actually declares X yet," say so explicitly rather than building past it or assuming it away. This matters most for the catalog/manifest system, where declaring more than the data model supports would produce silently wrong behavior later.
- Test your own new code's rejection paths (unknown actions, malformed input, invalid payloads) as reflexively as its happy path — before considering it verified.
- Comments on security-relevant lines should state the property being protected ("X can never happen because Y"), not just describe the mechanism.

Full reasoning and evidence for these lives in the Notion Baseleap Orchestrator doctrine (§3.3), added July 6 2026.

---

## WHAT THIS IS
The Baseleap Console — an internal agency tool Baseleap uses to win and onboard clients. A single-file HTML app (`index.html`) + a Vercel serverless AI proxy (`api/ai.js`), backed by Supabase (RLS on every table).
- Internal only. Not resold, not embedded in client GHL sub-accounts. Separate from Pulse (a client-facing product) and from the future master CRM.
- Houses a client-acquisition suite behind a business-switcher dropdown. One client = one row in the `clients` table.
- Five modules: Client Research, AI Audit Assistant, Automation Agent, Gap Report Builder, Proposal Generator. (Client Research is planned but not yet on the near-term roadmap below.)

## CURRENT BUILD TARGET
- Built: Console shell (auth + business-switcher + state-reset), AI proxy, Module 1 Audit Assistant, Module 2 Automation Agent Phase A (feasibility gate).
- Next: build-planner (Phase C) + Setup Agent → Proposal Generator + scope gate. (GHL capabilities reference + boundary map done → .claude/skills/ghl-automation + ghl-setup.)

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
- `gaps` — one row per atomic gap. Lifecycle: Audit Assistant writes `pending` (title/problem/cost/severity/category) → Automation Agent writes `feasible/mechanism/estimated_hours/approach` and flips to `validated`. Never let the Audit Assistant set `validated`. `matched_engine` is pattern metadata, NOT a retrieve guarantee: the sweep's DEPTH GUARD (`isDeepEngine` — live row must have `spec.manifest` + real workflow content) decides retrieve vs seeded formulate. A match requires `match_evidence` in the assessment JSON (enforced at parse, folded into rationale).
- `audit_sessions` — one row per audit (transcript/summary/status); gaps FK via `audit_session_id`.
- `build_plans` — parent record per engagement (post-agreement only). Build steps in dependency order, status `queued → building → testing → done`. Supports cross-agent step dependencies.
- `build_steps.manifest` / `build_steps.workflow` (JSONB, migration 008) — Build-Plan Depth. `manifest` = the field/tag manifest (`requires_tags`/`creates_tags`/`requires_fields`) on the engine's artifact step and on code-injected "create tags & fields" setup steps; `{"tbd":true}` exists only on HISTORICAL rows — the depth guard means a thin engine now formulates (with its own manifest) instead of retrieving empty. `workflow` = the structured node workflow (automations array; node types `trigger|guard|wait|action|update|condition|webhook|handoff|end` — webhook stays distinct from action, it marks the external/n8n boundary). Rendered only on step expand; PM layer (status/checklist/hours/notes) is untouched. GUARD RENDER RULE (locked July 8 2026): a guard IS a GHL if/else, so the node graph ALWAYS draws it as a fork — condition met → End pill, else → the remaining flow (cascading guards nest into successive forks, matching the real GHL canvas). Guard stays a SINGLE node in the data (`{type:"guard", config:"If X → end"}`); the fork is synthesized at render (`renderNodeGraph`) — never make the AI emit branch arrays on guards. MULTI-BRANCH (July 9 2026 — the old "3+-way split not expressible" gap is CLOSED): a guard/condition with 3+ outcomes carries a `branches:[{when, to:[nodes]}]` array — up to 5 condition branches (GHL's If/Else limit); the None/else path is the nodes that FOLLOW the node in the automation (the main flow — don't repeat it in branches). Formulate emits it; validated (`validateNodes`): ≤5 branches, each a non-empty `when` string + a non-empty `to` node array. A single-condition guard stays `config:"If X → end"` (rendered as the 2-branch if-met/if-not-met case). EMPTY-BRANCH AUTO-REPAIR (locked July 14 2026 — do NOT revert to a rejection): a `condition` node with exactly ONE empty branch (`yes` empty XOR `no` empty) is the recurring shape the model emits when it means a guard (one side stops, one continues). `validateNodes` → `normalizeLoneEmptyBranch` deterministically repairs it in place — the empty side becomes an explicit `{type:"end",config:"End"}`, the populated side stays — which renders identically to a guard (met→end / else→continue). Kept as `type:"condition"` (NOT converted to `type:"guard"`) ON PURPOSE: the canvas guard renderer consumes the FOLLOWING siblings as its continue-flow and ignores yes/no, so a literal guard conversion would silently DROP the populated branch. This SUPERSEDES prompt-only prevention (c79e2d4 empty-no + the symmetric empty-yes rule), which never converged across three occurrences. BOTH branches empty is still a real fallback-less If/Else and still THROWS — only the exact one-empty shape is repaired (a `console.warn` leaves an audit trail so an unusual spike in repairs is visible). NODE GRAPH (July 9 2026): nodes render as a TYPE LABEL only (Trigger/Guard/Action/…) on a dotted canvas — filled brand pill for the trigger start + End/Stop exits, flat color-coded cards for the rest, connectors as thin lines with a junction dot; a zoom control (40–200%, `S.buildPlan.zoom` + `pan`) sits bottom-right and the box is a drag-to-pan / wheel-zoom canvas. Clicking a node opens a popup with its details. GUARD/CONDITION RENDER (updated July 9): drawn as an explicit If/Else FORK (`renderFork`) — a bracket of branch columns (each labelled with its `when`; a single-condition guard = met→End / else→continue) plus a None column carrying the main flow. Cascading guards nest (staircase) like the real GHL canvas; pan/zoom navigates it. Guard stays a single data node; the fork is synthesized at render. Per-node OPTIONAL `deploy:{input,assets,guardrail}` bucket (inside `workflow` JSONB — no migration): `input` = what the operator enters for this client, `assets` = copy/links to attach (message nodes only), `guardrail` = what must not change here. The popup shows config + these three as labeled sections; formulate emits them (validated lenient), review_engine carries them by hand. Deployment split: `branding` + `never_touch` moved OUT of the side Deployment card into node popups (assets/guardrail); the card keeps changes_note, parameter_values (concrete per-client values), business_rules, overrides, spec_extras. Detail sidebar order: Manifest → Setup Checklist → Deployment → Notes.
- `build_steps.deployment` (JSONB, migration 009) — the full auto-generated deployment story on the engine's artifact step: `{ route, seeded_from, needs_review, changes_note, parameter_values, tiers, overrides, spec_extras }` (`seeded_from` = the thin catalog stub a formulation was seeded with, else null). Renders as the READ-ONLY collapsed "Deployment guide" section (⚠ REVIEW inline on the toggle for parameterize/formulate). `notes` holds ONLY operator-typed text on new plans; historical rows keep their old baked-in dump (never rewritten) with `deployment = NULL`.
- `build_steps.track` / `build_steps.phase` (migration 011) — ADDITIVE PREP, no UI yet. `track` (TEXT, default `'automation'`, CHECK `automation|agent|app`) = which product line the step belongs to, for a future unified multi-track build plan (CRM + Agent + App in one view); all existing rows backfilled to `'automation'` so current CRM-only plans are unchanged. `phase` (TEXT, nullable, no CHECK) = free-text label for that future phased view (vocabulary deliberately undefined; ordering still lives in `position`). NOTE: `track` != the existing `agent` column — `agent` (`setup|automation`) = which sub-agent builds the step; the shared string `'automation'` is intentional and semantically distinct. Names kept as-is by decision. Nothing reads/writes these two columns yet.
- DEPTH GUARD (retrieve-vs-create gate) — `classifyGapRoute` routes retrieve ONLY for engines passing `isDeepEngine` (live `spec.manifest` + every automation an object with steps/nodes). Thin/half-deep engines route to formulate SEEDED with their stub (`catalogSeedBlock`); `engine_key` stays null in the sweep result. Deepen the catalog row → route flips to retrieve, no code change. Assessment prompt carries per-engine DOES/NOT-FOR scope; stub matches estimate first-build hours.
- `engine_catalog.spec.manifest` — per-engine field/tag manifest, merged via `updateEngineManifest()` (browser console; same merge-not-overwrite pattern as `spec.deployment`). Seeded for the 5 deep engines only. Per-engine setup steps are COMPUTED from the union of manifests at plan generation (`injectManifestSetupSteps`) — never hand-listed by the AI.

## THE GAP LIFECYCLE (core contract)
A gap is the atomic unit that gets built, feasibility-checked, and priced (~1:1 to a sellable GHL automation). Audit Assistant identifies → Automation Agent qualifies → Gap Report reads only `validated`. Selection state (`proposed|accepted|declined`) drives BOTH the proposal and the build plan — one selection, two projections, always in sync.

## SCHEMA
Seven tables, RLS on all: `clients`, `audit_sessions`, `gaps`, `build_plans`, `gap_reports`, `proposals`, `client_files`. Schema changes are incremental — see `/migrations` (`ADD COLUMN IF NOT EXISTS`), run manually in the Supabase SQL editor.

## REASONING SKILLS
Each agent reads its skills in-context from `.claude/skills/<name>/SKILL.md` (curated/lean, not a dump). Build a skill alongside its agent, not up-front.

---

## WORKFLOW
1. Read this file, `REFERENCES.md`, and `MASTER_BUILD_GUIDE.md` (build sequence) + the relevant module section before starting. THE ONE RULE applies: the build target is the NEXT unbuilt item in dependency order — not whatever seems next.
2. Read the Notion track plan and the highest-priority incomplete item.
3. Explore the existing `index.html` for the pattern before adding a module — this repo has strong patterns; follow them.
4. Describe your approach with a written Definition of Done and wait for approval before implementing (plan mode). No approval without the Definition of Done.
5. Build → test → verify Supabase writes returned rows → ask before pushing.
6. If a data contract changed, update the in-repo guide in the same session.
7. STANDING CLOSING STEP (every Definition of Done): update the Console Operator SOP
   (Notion page "🖥️ Console Operator SOP" under the Console Build Spec) with the
   feature's operator-facing behavior — alongside bug-ledger and skill updates.
