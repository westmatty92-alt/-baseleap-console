# MASTER BUILD GUIDE — Baseleap Console

## Architecture
- Single-file `index.html` front end + one Vercel serverless function (`api/ai.js`) as the AI proxy.
- Supabase: auth (single operator) + Postgres (seven tables, RLS) + Storage (uploaded client files).
- Deploy: Vercel. Front end is static; `/api/ai` runs as a Node function.
- The console embeds into GHL at the agency level via a custom menu link (iframe) once live.

## State model
- `S` is the global state object. `S.activeClientId` drives everything.
- `loadClient(id)` → `resetClientState()` → load → `render()`. Always in that order.
- The selected client is the only context; modules read/write rows keyed to it.

## Known-bug checklist (run before every commit)
- [ ] No raw fetch to api.anthropic.com — all AI via `ai()` / `/api/ai`.
- [ ] Every insert stamps `operator_id` (RLS).
- [ ] New per-client state added to `resetClientState()`.
- [ ] Modal backgrounds hardcoded hex, not CSS vars.
- [ ] No duplicate `let`/`const` names inside a function (SyntaxError trap).
- [ ] Brace balance check passes.
- [ ] AI JSON parsed defensively (strip ```fences, wrap in try/catch) — or use a second extraction call.
- [ ] Large-output AI calls set an explicit adequate `max_tokens` AND were exercised live once, watching stop_reason/usage — mocked fixtures can't catch truncation (Bug #17, docs/BUG_LEDGER.md).
- [ ] Tested after deploy: hard refresh, check console for errors.
- [ ] Any AI output that later feeds a lookup (matched_engine → engine_key) is enum-validated
      at parse time against the shared const (KNOWN_ENGINE_KEYS) — never persisted free-text (Bug #18).

## Build-Plan Depth (manifest + node workflow — completeness by construction)
Engines DECLARE their tags/fields in `spec.manifest`; the planner COMPUTES per-engine
"create tags & fields" setup steps from the union of manifests (`injectManifestSetupSteps`)
and wires the dependency edges — setup is never hand-listed by the AI. First engine to
mention an item creates it (dedupe by exact name → keep manifest names BARE canonical
strings). A routed engine with no manifest gets a visible `{"tbd":true}` flag — never
fabricate a manifest from a thin spec. Formulate emits its own manifest + typed node
workflow (`trigger|guard|wait|action|update|condition|webhook|handoff|end`; final_rule
sentence first). Both persist on `build_steps.manifest`/`.workflow` (migration 008) and
render behind the step's "Node workflow & manifest" expand — the PM layer never changes.
Disclosure is NESTED: depth opens to manifest + a collapsed automation list (01 · Name…);
opening an automation shows final_rule + nodes immediately, with a collapsed per-automation
Tests sub-section below (tests travel inside `workflow`, so a graduated engine carries its
own test matrix). Formulate's tests validator is a lenient floor (≥ guards + conditions);
the full coverage matrix is enforced in the prompt only.
review_engine (seeded via upsertReviewEngine(), July 5 2026) is the FIRST PROVEN capture —
a real production engine in full Build-Plan Depth structure (4 automations with typed
nodes/final_rule/tests + manifest + deployment). It supersedes the thin review_request
row (left in place, historical); the Automation Agent's catalog prompt emits the
[engine_key: review_engine] so new assessments route retrieve, not formulate.
Deployment guide / notes split (migration 009): the artifact step persists the full
auto-generated deployment story on `build_steps.deployment`, rendered as a READ-ONLY
collapsed "Deployment guide" section (review marker inline on the toggle → changes made
→ parameter values → three tiers → overrides → engine-spec extras). `notes` = operator
text only on new plans; old plans keep their historical dump untouched.

Sweep concurrency (July 5 2026): parameterize/formulate AI calls run through a bounded
pool (SWEEP_CONCURRENCY = 5), results assigned by gap index so completion order never
affects output; drop-ins stay instant with no AI call. allSettled semantics — every gap
completes, any failure aborts generation with an aggregated error naming each failed
gap. Routing/validators/write path untouched (anti-backwards constraint); per-call
max_tokens + stop_reason checks live inside the unmodified call functions (Bug #17).

## Feasibility gate (the core business rule, enforced by data)
Gaps are written by the Audit Assistant with `validation_status = 'pending'`. The Automation Agent
sets `feasible`, `mechanism`, `estimated_hours`, and flips `validation_status` to `validated`.
The Gap Report Builder reads ONLY validated gaps. An unvalidated gap cannot reach the client.

## Pulse vs Console (don't confuse them)
- Pulse = client-facing product, deployed into client sub-accounts, resold. Separate repo.
- Console = internal, agency-level, one operator. This repo. No multi-tenant brand switching,
  no rebilling — but the client-switcher still needs the state-reset discipline above.
