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

## PM Tracker — lifecycle lens (Order 15, Aug 4 2026)

A **Tracker** subtab (`renderTracker()`/`renderTrackerBody()`, between Build Plan and
Proposal) that re-presents the SAME `S.buildPlan.steps` by lifecycle state instead of by
structural category. **THIS IS A LENS, NOT NEW MACHINERY** — and knowing that is what keeps a
future change from re-implementing it.

- **The lifecycle already existed and was already working.** `build_steps.status` has carried
  the live CHECK `queued|building|testing|done` since migration 005; `STATUS_STAGE` maps it to
  4 discrete stages; `setStepStatus()` writes it and stamps `completed_at`; `renderEngineRow`
  already drew the progress bar, the blocked-by label and the actionable highlight. Order 15
  added NONE of that. What it adds is the arrangement plus three facts the plan view computed
  and then discarded: the actionable QUEUE, blocker IMPACT, and `completed_at` (which had
  **zero read sites** anywhere in the app before this).
- **Four buckets, EXHAUSTIVE AND DISJOINT BY CONSTRUCTION** (`trackerBuckets`): `done` and
  `queued` are handled explicitly and everything else falls to in-flight, so every step lands
  in exactly one bucket and the four re-sum to `steps.length` — the Tracker can never
  disagree with the header total. The terminal else is a CATCH-ALL on purpose: a status added
  to the CHECK later surfaces visibly as in-flight instead of silently vanishing.
- Buckets are `position`-sorted, so the top of **Ready** is the genuine "do this next" —
  `position` is the plan's topological order.
- **`stepBlockers(s, opts)` / `isActionable(s)` are THE single definitions**, extracted from
  two inline copies (`renderEngineRow`, `renderTestGateSubRow`) so three surfaces can't drift.
  `opts.skipSameGap` is a **DISPLAY scope, not a truth change**: a nested test-gate is drawn
  under its own engine, so naming that engine is a redundant pointer at the row above — but
  the gate IS genuinely blocked by it, which is why the Tracker calls this WITHOUT the option
  and buckets such a gate as Blocked. Behavior identity with the old inline code is asserted
  over 300 randomized plans.
- **A DONE step never renders blocked-by.** Real plans contain done steps whose upstream deps
  are still queued (an operator completing work out of dependency order) — `stepBlockers`
  correctly still reports those deps, so the ROW guards on `s.status !== "done"`. Without it
  every such step displays a blocked-by list contradicting its own status. **Found on real
  data (`de43a1b1`), not by the fixtures** — the guard is on the LABEL only; the computation
  was never weakened to fix a display problem. NOTE: `renderEngineRow` still has this
  cosmetic issue and was deliberately left alone (out of scope) — candidate cleanup.
- **No new write path, no schema change.** Tracker rows drive the existing `setStepStatus()`;
  `build_steps` has exactly 3 update sites (status, checklist, notes) and only one writes
  status. The plan-level rollup is DERIVED and displayed only — `build_plans.status` is free
  text with NO CHECK constraint and is not written here.
- **Deferred, not dropped:** the `done`-click side effects from the original Order 15 text
  (3-audience SOP generation + deployed-system ledger write). Neither has a substrate today —
  a schema-wide search for `%ledger%`/`%sop%`/`%deployed%`/`%audience%` columns returns ZERO
  rows across all 11 tables, so "done writes the ledger" has literally nothing to write to
  until Order 16 exists. Also still absent: `import-build-plan-from-structured-input` (no such
  function anywhere in the repo) and any Baseleap-own client/plan row — which is why
  "Baseleap's own CRM plan = first test case" was not usable and `de43a1b1` was used instead.
- Verification: 53/53 harness assertions against the shipped source, plus the real 17-step
  plan partitioning 9 ready + 4 blocked + 0 in-flight + 4 done = 17, and a live browser check
  of the unblock cascade (marking `Sub-account foundation` done moved Ready 9→12, Blocked
  4→0, Done 4→5, total still 17; reverted, DB restored to `queued`/`completed_at` null).

## Order 16 — deployed-system ledger (v1, Aug 5 2026)

A `deployed_systems` table (migration 014) plus a **Deployed** card and a per-row
**Mark deployed** control on the Tracker. Plan + map: `docs/planning/order-16-deployed-systems-ledger.md`,
`docs/planning/order_16_deployed_systems_ledger.svg`.

- **It records an operator ASSERTION, not a derivation — that is the design, not a shortcut.**
  The Setup Agent creates exactly five kinds (tags, fields, custom values, calendars,
  pipelines) and **workflows are not among them**: engines are hand-built in GHL. `ghl_map`
  proves an asset exists but is flat; `setup_runs` proves a run happened but only over those
  five kinds. So "engine X is live for client Y" has no derivable source. Building it to
  *look* derived would have been the lie.
- **Grain = one deployed engine per client** — the gap ≈ engine ≈ sellable-unit grain.
- **Snapshot + pointer.** `title`/`engine_key`/`mode` are copied at write; `build_plan_id` and
  `build_step_id` are `ON DELETE SET NULL`. A plan delete cascades its steps away — the
  snapshot is what survives, which is the entire reason it exists.
- **Eligibility is `isDeployableEngine`, NOT `categorizeSteps().engines`.** The latter keeps
  unmatched test gates on purpose (render slot). On the real plan both return 4, so their
  agreement proves nothing; the divergence is asserted with a synthetic unmatched gate.
- **Not wired to the `done` click, by decision.** Done is a PM act; "live in a client's
  account" is a different claim. Confirm-gated, state-driven (`S.buildPlan.dep`), no native
  `confirm()`. `markDeployed` re-checks both guards rather than trusting the render.
- **Append-only except `removeDeployedSystem`** — a mis-assertion must be correctable.
  Partial `UNIQUE(build_step_id) WHERE NOT NULL` turns a double-mark into a message.
- **v1 never writes `engine_catalog`.** A `formulate` entry carries a read-only
  "graduation-eligible" label; the catalog is also the price sheet and graduation stays the
  operator's call. The ledger is the *evidence* a future graduation pass reads.
- **Delete guard extended:** the open-folder delete counts `deployed_systems` alongside
  `setup_runs`, and the blocked message names the actual condition(s).
- **Out of v1, deliberately:** 3-audience SOP generation (no substrate; the three audiences
  are undefined anywhere in the repo), the client-level cross-plan map (index.html:4122),
  supersession/re-deploy semantics, automatic graduation.
- **Verification honesty:** the DB contains no real deployed system — the four `done` steps on
  `de43a1b1` were completed inside a 7-second span on 2026-07-24, i.e. a click-through. A live
  test proves the mechanism, not that an engine shipped. 38/38 harness assertions run against
  the shipped source and the real 17-step plan.

## Order 15.92 — Setup run → build step evidence (Aug 6 2026)

The Setup Agent finishes a run and the build plan has no idea. Proven on live data: plan
`c0b5b431` has a **`complete` run** (`13909aeb`, 12 items created 2026-07-07) and **all five of
its setup steps are still `queued`**; across all three plans `setup_done = 0`. This order makes
that run's log legible on the step it belongs to. Map:
`docs/planning/order_15_92_setup_run_step_evidence.svg`.

- **The console gathers; the operator asserts.** Same doctrine as Order 16. Nothing is
  auto-checked and nothing is auto-`done`, because the run genuinely cannot prove the step's
  trailing human item (`Verify each item exists on a test contact`). Evidence is **derived on
  every render and never persisted**, so it cannot go stale against the DB.
- **It was never cosmetic.** `injectManifestSetupSteps` makes every engine `depends_on` its
  manifest setup step, and `stepBlockers` tests `status !== "done"`. So a successful run left
  every engine reading BLOCKED and the Tracker's Ready queue — the whole point of Order 15 —
  wrong about what to do next. **`done` is the only status that unblocks; there is no honest
  intermediate**, which is exactly why this is an assertion and not an auto-advance.
- **Eligibility is `isEvidenceBearingSetupStep` (`agent === "setup"` AND a real `manifest`),
  NOT `agent === "setup"`.** On the real plan only **1 of 5** setup steps qualifies. The other
  four (sub-account, A2P, email domain, GBP) carry `manifest = null`: the Setup Agent creates
  exactly five kinds and none of that work is among them, so no run can ever be evidence for
  them. `{tbd:true}` is the historical thin-engine placeholder and is excluded too.
- **The join is by LABEL LOOKUP, never by index.** `manifestLabelKeys` regenerates the exact
  strings the injector built the checklist from (`manifestItemKeys` + `fieldLabel`), because
  `owner` dedupe makes a later engine's checklist a **subset** of the manifest stored on it —
  index alignment would silently attribute the wrong key. Regenerating rather than parsing is
  also what survives a field name containing parentheses (`Review Credits Earned (Lifetime)`).
- **`created` and `found` both mean "exists now"**, which is the only question a checklist item
  asks; `error` is never evidence. Keys are lower-cased to match the case-insensitive union.
- **All runs, not the latest.** The loop is fail-stop, so a manifest can legitimately split
  across a failed run that created 8 of 12 and a later run that finished the rest — **a failed
  run's partial log is still true**, the fail-stop halts the loop and never undoes a create.
  Loaded ascending so the first success keeps its own timestamp. Chat runs are excluded *by
  construction* (`build_plan_id` null), not by a filter.
- **`[…]` param items can never be satisfied** — `setupManifestUnion` routes them to
  `paramItems` and the run never creates them, so no log entry can exist. They render as
  hand-work, never as a gap, and are excluded from the provable total.
- **No schema change, no migration, no new write path.** `build_steps` keeps exactly 3 update
  sites and the single status write stays `setStepStatus()`. `renderChecklistItems(step, ev)`
  gained an **optional additive** second arg — with it omitted the output is byte-identical to
  `main` (proved for 6 shapes), so the test-gate and detail-view renders are untouched.
- **`confirmAssertSetupStep` re-checks eligibility itself** rather than trusting the render that
  offered the button — same discipline as `markDeployed`. State-driven (`S.buildPlan.setupAssert`);
  no native `confirm()` anywhere in the file.
- **Out of scope, deliberately:** evidence on the Tracker's own setup rows (**now a named
  follow-up — Order 15.94 below**; v1 keeps the control in `renderSetupMini`, already the place
  setup status is advanced), and auto-writing `checklist[].done`.
- **FIX, same day — the evidence was load-time-only (`refreshPlanSetupRuns`).** Found the moment
  it met a real run: Matthew ran the Setup Agent against plan `de43a1b1` (run `549e7c6a`, 32 items
  created) and the surface still read 0. `S.buildPlan.runs` was written in exactly ONE place,
  `openBuildFolder`, and nothing refreshed it afterwards. **`confirmRunSetup` requires an open
  plan, so the folder is ALWAYS already open when a tab run starts** — meaning for a plan's first
  run the snapshot is necessarily empty and *cannot* update. That is a proof, not a diagnosis.
  `runSetupItems` now ends with `await refreshPlanSetupRuns(cfg.buildPlanId)`. It runs LAST, after
  the completion message has painted (the setup surfaces show no evidence, so nothing on screen
  waits on the query); it refreshes on FAILURE too, because a failed run's partial log is real
  evidence; and it is **guarded on the OPEN plan, not on planId alone** — a run takes tens of
  seconds and the operator can open a different folder mid-run, where an unconditional assignment
  would stamp this plan's runs onto that one, showing evidence for work done elsewhere, which is
  worse than showing none. A chat run (planId null) returns before querying. Verified 18/18
  against the shipped function with the DB/DOM boundaries mocked, including the exact reported
  scenario: 0/8 before → 8/8, 6/6, 8/8, 10/10 and 4/4 steps ready after.

## Order 15.94 — setup-run evidence on the Tracker rows (SCOPED, NOT BUILT)

Split out of Order 15.92 rather than folded into its fix. **The Tracker contains zero evidence
symbols** — `renderTrackerRow` shows title, status, blockers and `completed_at`, and nothing
about what a setup run proved. Order 15.92 put the evidence and the assert control in
`renderSetupMini`, on the **Build Plan** tab behind the **Setup** badge. That was a deliberate v1
boundary, but it is the wrong one in practice: the Tracker is the surface an operator reaches for
when asking "what can I do next", and a manifest setup step sitting in **Ready** is exactly the
row that a completed run has already satisfied.

- **What it needs:** `renderTrackerRow` gains the tally for `isEvidenceBearingSetupStep` rows, and
  probably the assert control too — otherwise the Tracker shows the fact and sends the operator
  to another tab to act on it.
- **What it must not do:** duplicate the derivation. `setupEvidenceMap`/`setupStepEvidence`/
  `setupStepProven` are already THE definitions and must stay single, in the same way
  `stepBlockers` was extracted from two inline copies in Order 15.
- **Prerequisite already satisfied:** `S.buildPlan.runs` is now live rather than load-time-only
  (the 15.92 fix above), so the Tracker would read fresh evidence without further plumbing.
- **Open question for the operator:** whether the assert control belongs on two surfaces at once,
  or whether the Tracker row should link to the Build Plan step instead. Worth deciding before
  building, not after.
- **Verification:** 51 synthetic + 12 real-data + 12 cascade + 6 additive-identity assertions,
  all against the shipped source. Real plan `c0b5b431` resolves **12 of 12** on the manifest step
  and **0/0, never ready, never eligible** on all four foundational steps. Cascade run on the
  real 7-step graph: asserting the manifest step removes it from both dependents' blocker lists,
  the engine drops 5 blockers → 4, buckets re-sum. **Honest limit: no live browser click-through
  was performed** — no local server, and a localhost origin carries no Supabase session. The
  offline render (real rows, shipped CSS) was inspected visually instead.

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
**SUPERSEDED IN PART (Aug 3 2026) — see "Setup Agent chat — live execution" below.** The
July 30 cycle described here was LAYOUT + STATE WIRING ONLY: an empty shell with an inert
composer, no AI call, no message model, no persistence, no DB work. The nav-override and
layout rules in this section are still exactly true and still binding. What is NO LONGER
true is "inert": the chat now carries a message model, a confirmation gate and real GHL
writes. The Setup Agent content column remains untouched — settings, Run GHL setup, diff
preview, log and checklist keep their markup and behaviour.
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

## Setup Agent chat — live execution (Aug 3 2026) — documentation catching up to reality
The chat now runs real GHL setup through the SAME pipeline the build plan uses. Nothing is
forked: the fail-stop loop, the throwing per-kind dispatch and the found/create idempotency
exist in exactly one place (`runSetupItems`). A chat request builds a SYNTHETIC step
(`[{manifest}]`) with NO `build_steps` row behind it and feeds it through
`setupManifestUnion` → `computeSetupDiff` → `runSetupItems`.
- **NAMESPACE THE PREVIEW, LOCK THE EXECUTION.** `S.setup.tab` and `S.setup.chat` each own
  `preflight`/`diff`/`busy`/`msg`. Sharing them is a SILENT WRONG WRITE — a chat preview
  overwriting the tab's diff would make the tab's Confirm create the CHAT's items while the
  operator believes they approved the plan's, with no error and no symptom. Execution is the
  opposite: ONE client-wide lock, because two runs against one sub-account both preflighted
  the same inventory (both attempt the same create; calendars/custom values/pipelines have NO
  duplicate-create recovery) and the stale-run sweep would mark the other run failed
  mid-flight. `running` is an OWNER TAG (`null|"tab"|"chat"`) so the blocked surface can say
  WHY; falsy when idle so existing truthiness checks hold. It REJECTS rather than queues — a
  queued run would execute against a stale preflight.
- **Cross-invalidation** via `invalidateSetupPreviews()`: any completed run, or any connection
  change, clears BOTH namespaces' preflight/diff plus `chat.pending`. Whatever made one
  surface's cached inventory wrong made the other's wrong too.
- **Chat runs carry `build_plan_id: null`** (so they never block a build's deletion via
  `deleteBuild`'s count) and `checklist: []` (`humanChecklistTemplate` is build-scoped
  foundational work a one-off request must never reset). `loadSetupData` therefore filters
  `.not("build_plan_id","is",null)` so `S.setup.run` stays the PLAN pointer — without it a
  reload after any chat run would render the tab's checklist card EMPTY.
- **Interrupted-run sweep is DB-DRIVEN, not pointer-driven**: every still-`running` row for
  the client, regardless of `build_plan_id`. A pointer-driven sweep could never reach a chat
  run (filtered out of `loadSetupData`) and missed older orphaned plan runs beyond `limit(1)`.
- **PROVEN LIVE IN PRODUCTION (not just by harness).** Commit 2's "NOT VERIFIED" list is now
  closed except the AI layer. A real chat request created calendar "deliveries" in 123
  Business's live sub-account, cross-verified at four independent layers:
  `setup_runs` row `60f985cd` (`build_plan_id` NULL — the first-ever chat-origin row —
  `status` complete, `checklist` length 0) → its single log entry
  `{kind:"calendar", name:"deliveries", action:"created", ghl_id:"6uZbRMQC8Ky8VgV16B5k"}` →
  `clients.ghl_map.calendars.deliveries` holding that same id → a live `list_calendars`
  showing 8 calendars including `deliveries` at that id. So `preflightSetup("chat")`, the
  diff render, Confirm, and `runSetupItems({origin:"chat"})` are all live-proven.
- **The `loadSetupData` exclusion filter is no longer vacuous.** With the chat run as the
  NEWEST row the two queries finally diverge: unfiltered returns the chat run
  (`checklist_len` 0), filtered returns plan run `13909aeb` (`checklist_len` 5) — exactly the
  bug the filter prevents.
- Harness: 102/102 assertions against the shipped source (extract-and-eval, not retyped
  copies) covering the lock in both directions, namespace independence, cross-invalidation,
  gate behaviour with and without a plan, and that the fail-stop loop / throwing dispatch /
  `setup_runs` insert each appear exactly once. **Commit 3 raised this to 161/161.**

## Setup Agent chat — the AI layer (commit 3, Aug 4 2026)

`proposeChatManifest` is no longer a regex stand-in: it is a real `ai()` call, and it is the
ONLY AI in the chat path. Everything downstream (preflight → diff → confirmation gate →
`runSetupItems` → GHL writes) is deterministic and was not touched.

- **Output is a DISCRIMINATED UNION**, which is what makes refusing a first-class response
  rather than a degenerate manifest: `{action:"propose", summary, manifest}` or
  `{action:"reply", message}`. A `reply` covers all three non-propose cases — out of scope,
  needs clarification (a pipeline with no stages given), or a question — and returns to the
  operator as text. **A `reply` STOPS BEFORE `preflightSetup`**: no inventory read, no diff,
  no confirm button. A manifest attached to a `reply` by a hedging model is ignored by
  construction, because `sendSetupChat` returns before anything reads it.
- **Scope is exactly the five supported kinds** (tags, fields, custom values, calendars,
  pipelines) — the ones `runSetupItems` can actually write. `SETUP_CHAT_SYSTEM` states three
  rules that are real properties of the pipeline, not style: setup ONLY CREATES (never
  deletes, renames or edits — `missingByName` leaves anything existing untouched); no
  bracketed placeholders (they route to `paramItems` and are never created); stage `position`
  is never authored (derived from array index). Out of scope → say plainly what setup can and
  cannot do and STOP — never approximate the request with a manifest, never propose a
  near-miss item instead.
- **The AI is deliberately BLIND to the live inventory.** It is a text→manifest translator;
  "does this already exist" is answered by `computeSetupDiff` against a fresh preflight,
  which stays the single source of truth.
- **VALIDATION CHAIN, every response, before anything reaches the pipeline:** `JSON.parse`
  (fences stripped) → `validateChatProposal` (discriminated shape) → **`validateManifest`,
  the existing shared validator, UNMODIFIED** → `hardenChatManifest`. Any failure stops with
  an operator-facing chat message and zero writes.
- **`hardenChatManifest` is chat-only and ADDITIVE** — it closes three ways a manifest passes
  `validateManifest` yet still produces a SILENTLY WRONG write, so it must not be folded into
  the shared validator (that would change formulate's behavior):
  1. **Field type vocabulary.** `validateManifest` requires only a non-empty string and
     `setupFieldItem` does `GHL_DATATYPE[type] || "TEXT"` — so `type:"dropdown"` would be
     silently created as a TEXT field. Rejected. A *capitalized* type (`"Number"`) is
     plausible model output and would ALSO silently fall back to TEXT, so it is accepted
     case-insensitively and CANONICALIZED to lowercase.
  2. **Unknown top-level keys.** `validateManifest` ignores them and `setupManifestUnion`
     never reads them, so an invented sixth kind (`requires_workflows`) would be silently
     DROPPED while the summary still claimed it — the diff would contradict its own summary.
  3. **Duplicate pipeline stage names.** Nothing upstream checks this: `setupPipelineItem`
     maps stages to `{name, position:i}` and posts them, so duplicates would both be created.
     Checked case- and whitespace-insensitively.
  Plus placeholder-bracket rejection and an empty-manifest guard.
- `aiJsonWithRetry` is reused, inheriting its doctrine unchanged (one retry on a CONTRACT
  VIOLATION only with the named violation fed back; transport and truncation errors propagate
  immediately). Two additive params: `history` for multi-turn, and `tag` for the console
  prefix so chat failures don't log under `[sweep]`.
- `chatHistoryForAi()` exists for three hard Messages-API constraints, each of which
  otherwise costs a 400 or a wasted turn: consecutive same-role turns are MERGED (Cancel
  straight after a proposal pushes two agent turns in a row), leading assistant turns are
  dropped (the first message must be user), and history is capped at 10 prior turns. The
  CURRENT user message is excluded — `aiJsonWithRetry` appends it.
- `chatSetupContext()` is read-only and makes **no extra API calls** — client, gate state and
  the build plan's `setupManifestUnion` summary, all already in memory. This is what makes
  the panel's own empty-state promise ("what the run will create, what already exists, or why
  a step is blocked") honest; anything outside it the AI is told to decline rather than guess.
- **NOT mechanically detectable, stated so it isn't mistaken for covered:** a summary that
  misdescribes its own manifest. No validator can catch that. The control is the confirmation
  gate — the operator confirms against the rendered diff, never the summary text.
- Harness: 161/161 against the shipped source, including an adversarial band of
  passes-structural-checks-but-subtly-wrong cases (empty-string custom value, duplicate and
  case-differing stages, bad/null field object, out-of-vocabulary and capitalized types,
  invented sixth kind, stages as objects, placeholder name and value, empty manifest) plus
  retry doctrine and history mapping. The AI itself is stubbed with canned raw output — see
  the next line.
- **PROVEN LIVE (Aug 4 2026 — this bullet previously read "LIVE-UNVERIFIED at commit time").**
  `/api/ai` 501s on localhost, so the harness could only stub the AI; the real model's
  behavior was tested by operator against the `215ff94` preview
  (`baseleap-console-4owwdsqb3`, deployed 21:38:11Z), five cases including the one that
  mattered most — **an out-of-scope request produced a plain refusal and NO diff**, so the
  scope rule holds against a real model and not just against canned output.
- **What the DB corroborates, and what it structurally cannot.** Case 1 left a real audit
  trail: `setup_runs` `70c9c628` at 21:43:27Z (5 min after that deploy), `build_plan_id` NULL
  + `checklist` [] = a chat run, one log entry creating calendar `g money`
  (`fNKN8F5xtXDG4fJB8ML0`), finished in 620ms. Note the name is stored VERBATIM — lowercase,
  not title-cased — which is direct evidence the prompt's "do not rephrase, title-case or
  improve their wording" rule held on live output. **The refusal path leaves NO server-side
  trace by design** — no `setup_runs` row, no `ghl_map` entry, no GHL call — so case 2 rests
  on the operator's direct observation and nothing else can ever corroborate it. That is the
  correct behavior (a refusal must write nothing), not a gap in the evidence.

## Feasibility gate (the core business rule, enforced by data)
Gaps are written by the Audit Assistant with `validation_status = 'pending'`. The Automation Agent
sets `feasible`, `mechanism`, `estimated_hours`, and flips `validation_status` to `validated`.
The Gap Report Builder reads ONLY validated gaps. An unvalidated gap cannot reach the client.

## Pulse vs Console (don't confuse them)
- Pulse = client-facing product, deployed into client sub-accounts, resold. Separate repo.
- Console = internal, agency-level, one operator. This repo. No multi-tenant brand switching,
  no rebilling — but the client-switcher still needs the state-reset discipline above.
