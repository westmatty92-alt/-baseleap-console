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
- [ ] New print-CSS reserved space (an @page margin, header, or footer band) has its OWN background set — an @page margin area is outside the box model, no element background (html/body/anything) paints into it (Bug #20).

## Build-Plan Depth (manifest + node workflow — completeness by construction)
Engines DECLARE their tags/fields in `spec.manifest`; the planner COMPUTES per-engine
"create tags & fields" setup steps from the union of manifests (`injectManifestSetupSteps`)
and wires the dependency edges — setup is never hand-listed by the AI. First engine to
mention an item creates it (dedupe by exact name → keep manifest names BARE canonical
strings). Formulate emits its own manifest + typed node
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
Completion signal parameterized (July 5 2026): automation 1's trigger is the per-client
`completion_trigger` parameter — Appointment Status = Showed (appointment businesses) OR
pipeline stage = Job Complete/Won (contractors) — so review gaps match for both shapes;
credit/cap/dedupe automations 2-4 are signal-independent and unchanged. Re-run
`upsertReviewEngine()` after pulling this change so the live row carries the new
parameter. `depends_on` still lists booking (appointment shape) — pipeline clients see a
harmless booking scope-flag hint; making depends_on conditional is deferred.
Deployment guide / notes split (migration 009): the artifact step persists the full
auto-generated deployment story on `build_steps.deployment`, rendered as a READ-ONLY
collapsed "Deployment guide" section (review marker inline on the toggle → changes made
→ parameter values → three tiers → overrides → engine-spec extras). `notes` = operator
text only on new plans; old plans keep their historical dump untouched.

Retrieve-vs-create gate (July 5 2026): `matched_engine` no longer implies retrieve — it is
pattern metadata; the route is decided in data by the DEPTH GUARD (`isDeepEngine`): retrieve
requires the LIVE catalog row to carry `spec.manifest` AND real workflow content (every
automation an object with steps/nodes). An engine failing the guard routes to SEEDED
FORMULATE — the stub's summary/pattern/manifest/deployment/client_parameters feed the
formulate prompt as constraints (`catalogSeedBlock`), the sweep result keeps
`engine_key: null` (a stub never counts as a delivered engine for foundation logic),
carries `seeded_from` for provenance (persisted in `build_steps.deployment`), and inherits
the stub's `depends_on`. Consequence: new plans can no longer produce `{"tbd":true}`
manifests (the flag renders only on historical rows); deepening a catalog spec flips its
route to retrieve with zero code change. Assessment side: the catalog prompt carries
per-engine DOES / NOT FOR scope and a retrieve-vs-create Matching rule; `match_evidence`
is required in the JSON whenever `matched_engine` is set (enforced in
`parseAssessResponse`, folded into rationale — no schema change); stub matches estimate
FIRST-BUILD hours with `templated:false`.

Sweep concurrency (July 5 2026): parameterize/formulate AI calls run through a bounded
pool (SWEEP_CONCURRENCY = 5), results assigned by gap index so completion order never
affects output; drop-ins stay instant with no AI call. allSettled semantics — every gap
completes, any failure aborts generation with an aggregated error naming each failed
gap. Routing/validators/write path untouched (anti-backwards constraint); per-call
max_tokens + stop_reason checks live inside the unmodified call functions (Bug #17).

## Builds module — navigation restructure & folder-scoped tabs (locked July 18 2026; plan: docs/planning/nav-restructure-builds-tabs.md)
The left-nav "Automation agent" becomes **Builds**; "Gap report" and "Proposal" are
removed as separate nav items. All five surfaces move to live as TABS INSIDE each build
folder, confirmed order: **Feasibility → Gap Report → Finalize → Build Plan → Proposal**.
The folder GRID (one card per `build_plans` row) is unchanged; opening a folder shows a
5-tab shell. Organizing principle: **Feasibility is the shared client-level gap-qualification
layer; everything downstream of "which gaps are in this build" is folder-scoped and FROZEN
with the saved build.**
- **Scope binding (migration 012, `build_plan_gaps`):** per-folder gap scope. `build_plan_id`
  → ON DELETE CASCADE; `gap_id` → NO cascade (the folder's frozen snapshot must survive a
  client-pool gap edit; a since-deleted gap renders "— gap no longer in catalog"). `selection`
  CHECK `accepted|declined`, `UNIQUE(build_plan_id, gap_id)`, RLS on `operator_id`. The
  client-level `gaps.selection` is RETAINED-BUT-DORMANT (additive-only; build scope now reads
  `build_plan_gaps`). Table count moves seven → eight once 012 is live.
- **Flow 2 (draft-then-save, unchanged safety):** the 5-tab shell renders for a build in BOTH
  an unsaved draft (Finalize ACTIVE, Gap Report/Proposal live previews, Build Plan = draft
  review) and a saved folder. NOTHING is written until Save, which commits `build_plans` +
  `build_steps` + `build_plan_gaps` atomically — no empty pre-created folders.
- **Bimodal Finalize:** ACTIVE picker pre-save (accept/decline/reset → draft selection, not
  client `gaps.selection`); read-only **"Scope locked"** record post-save (Volt lock banner +
  one-line immutable-record explanation + an ENABLED, pre-seeded "+ Start a new build to
  re-scope" CTA + read-only ✓ scope rows, no accept/decline bar). Re-scoping a saved build =
  a NEW build (append-only); scope is never re-edited in place.
- **Gap Report / Proposal (built fresh, folder-scoped):** documents generated from the
  folder's FROZEN `build_plan_gaps`; regenerable as documents WITHOUT changing scope. This
  cycle wires their tab placement + scope binding only; full generation/copy is a follow-on
  per module (`gap_reports`/`proposals` gain `build_plan_id`; column set designed then).
  **REVISED after this cycle:** Gap Report is now CLIENT-LEVEL (the full set of validated
  gaps for the client, NOT folder-scoped — mirrors Feasibility; see the `gaps` contract) and
  renders AI-SYNTHESIZED client-facing copy (`gaps.client_copy`, two-phase, migration 013,
  Order 15.997). Proposal stays per-build / folder-scoped and unchanged. Proposal copy
  generation is still the open follow-on.
- **Delete inside an open folder (block + archive):** count `setup_runs` for the plan. 0 runs
  → verified hard-delete (`.delete().select()`; `build_steps` + `build_plan_gaps` cascade) →
  grid. ≥1 run → BLOCKED (the `setup_runs.build_plan_id` FK is NO ACTION / RESTRICT-like) with
  an explanation + archive via `build_plans.status = 'archived'`. `setup_runs` is NEVER
  deleted — it is the provisioning audit trail the RESTRICT protects. All writes `.select()`-verified.
- Build order (each its own review): 012 schema → nav rename + subtab removal + tab-shell
  scaffold → Finalize folder-scoped + `build_plan_gaps` wiring → scope-locked post-save →
  delete + archive → Gap Report/Proposal placement. Out of scope of THAT cycle: retiring
  `gaps.selection`, System Composer (Order 15.99). (Gap Report copy: DONE — Order 15.997,
  migration 013. Proposal copy: still pending.)

## Saved build plan — row categories + header step breakdown (Aug 3 2026)
A saved plan's `build_steps` rows fall into THREE render slots, and the header total must be
derivable from what is on screen. `categorizeSteps(steps)` is the SINGLE categorization —
`renderSavedPlan`'s header breakdown AND `renderPlanSection`'s badge/table both call it, so a
row can never be counted as one kind and drawn as another.
- **The three categories:** `setup` (`agent === 'setup'` — never a table row; summarized in the
  section's **Setup ✓/○ n/m** badge, status editable via `renderSetupMini`) · `engines` (the
  top-level `.bp-row` table rows) · `gates` (test-gates nested inside their engine's dropdown).
- **EXHAUSTIVE + DISJOINT BY CONSTRUCTION:** setup is filtered out first and `partitionTestGates`
  splits the exact remainder, so `setup + engines + gates === steps.length` ALWAYS — the header
  cannot contradict its own total. An UNMATCHED test-gate (no marker/workflow-sibling) stays in
  `engines` ON PURPOSE: that is the slot it actually renders in. Do not "fix" this by filtering
  gates out of `engines` — the two must agree with the render, not with the title convention.
- **Header line:** `4 of 17 steps done · 4/4 engines · 0/9 setup · 0/4 test gates`. The total is
  unchanged and still counts every row (it was never wrong); the appended component fractions are
  what make 17 derivable. **A zero-length category is OMITTED, never printed as `0/0`.** Segment
  order is engines → setup → test gates (engines first = what the table shows). Empty plan
  degrades to the bare `0 of 0 steps done`.
- **THE BUG THIS FIXES** (reported Aug 3 2026): the header read `4 of 17` beside four visible
  all-Done rows. 17 was CORRECT (9 setup + 4 engines + 4 test-gates) but underivable — the 9 were
  double-reported (inside 17 *and* as `Setup 0/9`) and the 4 gates were one expand-click deep.
  The defect was legibility, not arithmetic; the fix adds no filtering and changes no total.
- **Contrast note:** hierarchy comes from STRENGTHENING the total (`.bp-head-total`,
  `var(--ink)` + weight 600), NOT from fading the components — `.msg` is already 12px
  `var(--muted)`, so dimming further lands near 3:1. Don't re-add a muted class on the parts.
- **Section pill (follow-on, same night):** the `.bp-sec-roll` rollup carries the SAME kind of
  breakdown, MINUS whatever the ADJACENT Setup badge already shows —
  `4/17 complete · 4/4 engines · 0/4 test gates` beside `Setup ○ 0/9`. Built by the same
  builder via `renderStepBreakdown(steps, {omit:["setup"]})`; the header passes no opts and is
  byte-identical to before, so the two can never drift in wording or pluralization.
  **THE ROW INVARIANT — setup is stated EXACTLY ONCE per section row:** the pill omits it
  because the badge carries it, and when a track has NO setup steps the badge is not rendered
  AND the zero-length rule drops the segment, so it is stated zero times rather than once in
  the wrong place. Both sides key off the same `setup.length` predicate, so the
  complementarity holds BY CONSTRUCTION, not by two rules happening to agree.
  **Two rejected designs, do not "simplify" back into either:** (1) giving the pill all three
  segments re-creates the adjacent double-report this whole fix removed — the badge sits
  inches away, and with one track it also duplicates the header string verbatim one line
  above; (2) engines-only (`4/4 engines`) is the ORIGINAL BUG IN MINIATURE — on a collapsed
  section it reads as "track finished" while test-gates and setup are still outstanding.
  Layout verified by measured probe: single line down to 480px section width, graceful WRAP at
  420px (bar height 38 → 54), never clipped, never overlapping the badge, no horizontal body
  scroll.
- Render-only change: zero DB writes, no schema/migration, `build_steps` untouched. The folder
  grid card (`planCounts` — `N engines · N steps`) is a separate surface and independently
  corroborates (`4 engines · 17 steps`).

## Gap Report — client-facing Preview / print view (branded; on `fix/condition-empty-branch-autorepair`, not yet merged)
A separate presentational view (`.cr-*` classes, `renderClientReport()`/`openClientReport()`/
`closeClientReport()`) over the operator Gap Report tab — a **Preview** button opens a
full-screen branded report; **Print / Save as PDF** inside it calls `window.print()`. Reuses
`clientReportGaps()` (= `clientValidatedGaps()` minus declined, filtered to
`client_copy.phase === 'complete'` only) — no new AI calls, no new DB reads/writes, no pricing.
- **Cover (final, round 4):** a real photographed laptop-on-desk asset
  (`assets/cover-laptop.png`, full-bleed background on `.cr-photo-band`) with the BASELEAP
  wordmark baked directly into the photo (no separate logo layer). The laptop's own screen
  area is masked in the source asset; the abstract CSS dashboard hero (`crHero()` — REAL
  gap-derived counts only: total/high/med+low tiles, severity-split bars, a purely decorative
  unlabeled donut, no fabricated figures) is composited on top via `.cr-hero`/`.cr-dash`
  (`left/top/width/height` percentages, manually placed and pixel-verified against the photo's
  actual screen boundary — NOT CSS `transform:scale()`, which proved unreliable across repeated
  measurement; direct width/height % + `overflow:hidden` is the trustworthy pattern here).
  `Prepared for {business_name}` pulls from `S.activeClient.business_name` live — confirmed both
  the gap counts and the client name are genuinely dynamic per report, not fixed to any one
  test client.
- **Full dark theme:** Midnight background throughout (cover AND body pages, not just the
  cover). Gap titles/section headers/dividers/ancillary text → Volt; sub-labels → `#F4F5F0`;
  body copy → white; severity accents brightened for dark-background legibility; the
  Recommended-starting-point callout is a slightly elevated surface so it doesn't blend into
  the page.
- **Print fidelity:** `@page{margin:0}` makes the dark fill genuinely edge-to-edge (verified by
  rasterizing the print-PDF and sampling every page's four corners — no white margin frame).
  The closing callout + footer band are wrapped in `.cr-close{page-break-inside:avoid}` so they
  move together as one adaptive unit only if they don't fit on the last content page — no
  unconditional forced break (rejected earlier: it re-creates a near-empty trailing page).
- **Gate:** a validated gap only appears once `client_copy.phase === 'complete'`; the operator
  tab shows an "N gaps not yet client-ready" note and disables Preview until at least one gap
  qualifies.
- Verified via real code extraction (not retyped) + actual headless-Chrome print-to-PDF
  rendering, page-by-page, at every round — not visual description alone.

## Setup Agent chat panel — layout shell & derived nav override (July 30 2026; map: docs/planning/setup_chat_nav_derived_state.svg/.png)
THIS CYCLE IS LAYOUT + STATE WIRING ONLY. The chat renders as an EMPTY SHELL (header,
message region, inert composer) — no AI call, no message model, no persistence, no DB
work. Chat behaviour is a separate follow-on. The Setup Agent content column is
untouched: settings, Run GHL setup, diff preview, log and checklist keep their exact
markup and behaviour.
- **Two independent sidebar classes, one visual result.** `#app.nav-collapsed` = the
  operator's PERSISTED preference (☰ / `toggleNav()` / `localStorage bl_nav_collapsed`).
  `#app.nav-forced` = a TRANSIENT override applied while the chat is open. `setNavForced(on)`
  toggles ONLY the class — it never reads or writes the pref key, which is what makes
  releasing the override restore whatever the operator had (collapsed OR expanded) with no
  special-casing. The two selectors are GROUPED in CSS so they can never drift.
  `localStorage.setItem` appears exactly ONCE in the whole file (inside `toggleNav`) — the
  chat path provably cannot touch the preference.
- **The override is DERIVED, never set imperatively.** One line, the first statement of
  `render()`: `setNavForced(!!S.activeClient && S.module === "setup" && !!S.setup.chatOpen)`.
  All four release paths — chat close, module switch, client switch, no-client — already
  funnel through `render()`, so they clear it by construction rather than by remembering.
  THE `!!S.activeClient` TERM IS LOAD-BEARING and being above the early return is NOT
  sufficient on its own: with no client, `S.module` is still `"setup"` and `chatOpen` is
  still true, so without it the override sticks while the early return replaces `#content`
  with the empty-client message — destroying the chat's own ✕, with ☰ unable to recover the
  sidebar (`nav-forced` hides it independently of `nav-collapsed`). Soft-lock survivable
  only by reload. Caught by verification test 5b; do NOT drop the term.
- **`chatOpen` lives in `freshSetup()`**, so `resetClientState()` closes the chat on client
  switch — a chat opened against client A can never survive into client B. `resetClientState()`
  itself is unmodified (it already calls `freshSetup()`).
- **Three-column split INSIDE `.content`** (`.setup-split` flex row: `.setup-col` + `.setup-chat`),
  emitted by `renderSetup()` only when `chatOpen`. `.content`'s own CSS is deliberately
  UNTOUCHED — it is the shared scroll container for all four modules. The topbar is unaffected
  and still spans full width.
- **The chat column is a SIBLING of `#setup-body`, never a child.** `renderSetupBody()`
  re-renders `#setup-body` alone after every setup action and after the initial load; nesting
  the chat inside it would wipe composer text and scroll position each time.
- **`--topbar-h:67px`** (`:root`) is a REAL MEASURED value (14+14 padding + 1 border + 38
  tallest child, the client-switch select), and is APPLIED to `.topbar` as an explicit height
  — not merely consumed by `calc()` — so the variable and the element cannot drift. The chat
  column's `height:calc(100vh - 48px - var(--topbar-h))` depends on it being true, not
  assumed. Consequence: the topbar is now a PINNED height; a taller control added to it must
  bump `--topbar-h` in the same change or it will clip.
- Verified by a harness that extracts the real CSS, the real `#app` markup and the real
  functions under test out of `index.html` (only the data layer stubbed): 9/9 checks,
  including localStorage read before/after both round-trips and a DOM-identity check that the
  chat panel survives `renderSetupBody()` with composer text and scrollTop intact.

## Feasibility gate (the core business rule, enforced by data)
Gaps are written by the Audit Assistant with `validation_status = 'pending'`. The Automation Agent
sets `feasible`, `mechanism`, `estimated_hours`, and flips `validation_status` to `validated`.
The Gap Report Builder reads ONLY validated gaps. An unvalidated gap cannot reach the client.

## Pulse vs Console (don't confuse them)
- Pulse = client-facing product, deployed into client sub-accounts, resold. Separate repo.
- Console = internal, agency-level, one operator. This repo. No multi-tenant brand switching,
  no rebilling — but the client-switcher still needs the state-reset discipline above.
