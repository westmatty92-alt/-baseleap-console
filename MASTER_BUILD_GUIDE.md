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
  `build_steps` had exactly 3 update sites (status, checklist, notes) and only one wrote
  status. **Superseded by Order 16.1: there are now 4 sites and 2 status writers.** The plan-level rollup is DERIVED and displayed only — `build_plans.status` is free
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
- **Out of scope at the time:** evidence on the Tracker's own setup rows (**built by Order 16.1;
  15.94 is ABSORBED, not open**; v1 keeps the control in `renderSetupMini`, already the place
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
  worse than showing none. A chat run (planId null) returns before querying. Verified 27/27
  against the shipped function with the DB/DOM boundaries mocked, including the exact reported
  scenario (0/8 before → 8/8, 6/6, 8/8, 10/10 and 4/4 steps ready after) and the chat-origin
  chain proved rather than assumed: two call sites, chat's literal null, zero round-trips.
- **Verification:** 51 synthetic + 12 real-data + 12 cascade + 6 additive-identity assertions,
  all against the shipped source. Real plan `c0b5b431` resolves **12 of 12** on the manifest step
  and **0/0, never ready, never eligible** on all four foundational steps. Cascade run on the
  real 7-step graph: asserting the manifest step removes it from both dependents' blocker lists,
  the engine drops 5 blockers → 4, buckets re-sum. **Honest limit: no live browser click-through
  was performed** — no local server, and a localhost origin carries no Supabase session. The
  offline render (real rows, shipped CSS) was inspected visually instead. With the fix's 27
  above, the suite totals **108/108** — matching commit `2443a7d`'s message.

## Order 15.94 — setup-run evidence on the Tracker rows (ABSORBED INTO ORDER 16.1)

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
- **Status: ABSORBED.** Built as part of Order 16.1 below, together with auto-completion — the
  two were inseparable in practice: a step that moves on its own is only trustworthy if the
  surface shows why it moved. The open question above was answered by building the tally on the
  Tracker and leaving the manual assert control on the Build Plan tab, since after 16.1 the
  manual path is the exception (a placeholder-bearing step) rather than the norm.

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

## Order 16.1 — setup steps auto-complete, with recorded provenance (Aug 6 2026)

Matthew opened the PM Tracker after a successful Setup Agent run and the setup steps still read
`queued`. His position, and it is correct: a step titled **"Create tags & fields — X"** exists to
create tags and custom fields; once the agent has created them, it is done. Absorbs Order 15.94.

- **The reversal, and why it is not a contradiction.** Order 15.92 made completion an operator
  ASSERTION because a run cannot prove the step's trailing `Verify each item exists on a test
  contact` line. That was the wrong call: the line is appended by `injectManifestSetupSteps`, it
  is not what the step is FOR. Tag and field creation **is** derivable from `setup_runs.log`, so
  it is now derived. **The assertion doctrine still stands where nothing can derive the claim —
  `deployed_systems` is the case it was written for, and is untouched.**
- **A second, stricter predicate — not a change to the first.** `setupStepFullyCreated` = every
  KEYED row has evidence. `setupStepProven().ready` is unchanged and still gates the MANUAL
  button, deliberately excluding `[…]` placeholders (a human can name the campaign tag and then
  legitimately call the step done). Auto-completion cannot make that judgement, so a
  placeholder-bearing step is false **by construction** and HOLDS — the console must never flip a
  step to done while a tag it declares does not exist in the account.
- **On real data:** plan `de43a1b1` auto-completes exactly positions 1, 2, 3 (6/6, 8/8, 10/10) and
  position 0 HOLDS at "8/8 created · 1+ needs hand-naming". Plan `c0b5b431` auto-completes its one
  manifest step (12/12). The 5 manifest-null foundational steps are never touched.
- **One rule, two entry points.** `reconcileSetupStepCompletion` is called from `openBuildFolder`
  AND `refreshPlanSetupRuns`, so the state is SELF-HEALING — a plan whose run predates this
  corrects itself the next time its folder opens, with no SQL backfill. **Only from `queued`:** any
  other status means an operator deliberately moved the step, and silently overriding an explicit
  human state is the surprise this codebase avoids. One batched `.update().in().select()`,
  re-rendered from the RETURNED rows; no query at all when nothing qualifies.
- **`build_steps.completed_by` (migration 015)** — TEXT, nullable, no CHECK (matching `phase`'s
  precedent). `done` can now arrive two ways, and without this the two are indistinguishable
  afterwards. It **cannot be recovered by inference** — an operator marking a fully-created step
  done from the dropdown looks identical at render time — so it is recorded at write time or not
  at all, which is why it shipped WITH the auto-complete rather than after: any completion
  predating the column is permanently unattributable. NULL on a done row = completed before 16.1,
  honestly unknown, **never backfilled by guessing**. Moves in lockstep with `completed_at`.
- **Tracker annotations.** `auto — Setup Agent` chip marks MACHINE completion only; `'operator'`
  and NULL render nothing, because the question an operator asks is "did the machine do this?" —
  the COLUMN still distinguishes them for anyone querying. The tally reuses THE evidence
  derivation, built once in `renderTrackerBody` and threaded down, never a second copy.
- **Verification:** 31 assertions for this order (predicate, real-data selection, reconcile guards,
  provenance lockstep, Tracker annotations) plus the 110-assertion existing suite — **141/141**.
  The prior suite grew from 108 to 110 because wiring reconcile into `refreshPlanSetupRuns` broke
  that harness's sandbox; fixing it added two assertions that the hand-off passes the same planId.
  One bogus assertion was found and replaced during the run: it asserted only that an async call
  returns a Promise, which is trivially true. **Live browser check not performed** (no local
  server; localhost carries no Supabase session).
- **Migration 015 must be run manually BEFORE this code is live** — the reconcile write targets a
  column that does not exist until then. Confirmed absent at build time.

## Order 16.7 — catalog graduation v1 (Aug 11 2026)

An operator-triggered action on the **Deployed** card that turns a proven, formulated,
deployed engine into an `engine_catalog` row. **No migration, no schema change.**
`graduationCase`/`graduationDeployment`/`graduationSpec`/`graduationSummarySeed`/
`confirmGraduate`/`loadGraduatedFrom`, `.grad-*`/`.dep-grad*`, index.html.
Map: `docs/planning/order_16_7_catalog_graduation.svg`/`.png`.

- **This closes Order 16's one deliberate omission.** v1 of the ledger rendered a read-only
  "graduation-eligible" chip and never wrote the catalog. Nothing triggered on that chip; the
  information existed nowhere else, and `deployed_systems` was empty, so the chip had never
  rendered at all. 16.7 makes the chip an action.
- **Never automatic.** "The Agent proposes; the operator confirms what graduates. Never
  auto-write — the catalog is also the price sheet." Confirm-gated, state-driven
  (`S.buildPlan.grad`), no native `confirm()`.
- **Shape (a) only — INSERT, `engine_key` must be null.** There are TWO graduation shapes and
  the ledger's `mode` alone cannot tell them apart: a `formulate` entry that *carries* an
  `engine_key` was seeded from a thin catalog engine via the depth guard (position 12 on
  `de43a1b1`, `seeded_from: booking`). Graduating that would MUTATE a curated row and flip its
  route from formulate-seeded to retrieve for **every future plan**. That is the *deepen* case,
  deferred; it renders as `deepen by hand`, not as a missing button.
- **`graduationCase(d, gmap)` is THE definition, and its ORDER is load-bearing.** `graduated`
  first (a fact about the past — still true after the plan is deleted), then `build_step_id`
  (ON DELETE SET NULL leaves a snapshot with no step, and graduation reads manifest+workflow
  off that step), then `mode`, then `engine_key`. `confirmGraduate` re-checks **every** one
  independently — the render offers, the function decides.
- **The deployment bucket is WHITELISTED, not copied.** `build_steps.deployment` is per-client:
  `parameter_values` holds this client's concrete values, `changes_note`/`overrides` describe
  one build, `route`/`seeded_from`/`needs_review` are that build's routing metadata. Only
  `tiers` + `spec_extras` cross over. A whitelist so a key added later is excluded by default
  rather than leaking until someone notices.
- **`band` and `first_build_hours` are OPERATOR-entered, never copied from the step** — the step
  records what one build cost, the catalog prices future work. They live in `spec` because
  `engine_catalog` has no such columns and no existing row carried them; band's real consumer
  today is the hardcoded assessment roster, which the operator edits by hand anyway.
- **A graduated engine is DEEP ON ARRIVAL.** `build_steps.workflow` elements carry `nodes`, so
  `spec.manifest` + `spec.automations` satisfies `isDeepEngine` — it routes `retrieve`, not
  formulate-seeded. Verified against the live row via the extracted function, with three
  controls returning false.
- **`spec.purpose` is written alongside `summary`.** `gapSolutionSource` tier 1 reads
  `spec.purpose || engine.summary`; without this every graduated engine falls through to the
  summary column for its client-facing copy — one field doing two jobs.
- **`summary` is the engine's BOUNDARY, not a description**, and it is genuinely load-bearing:
  read by `catalogSeedBlock` (formulate constraints), `adaptEngineToClient` (the parameterize
  prompt, which does NOT receive `spec.automations`), and `gapSolutionSource`. Every existing
  catalog summary encodes a negative — "never applies Paid", "never Payment Received",
  "Service-agnostic". It is NOT used for MATCHING; the roster that decides matches is hardcoded
  prose. Blank is rejected outright.
- **Duplicate graduation is blocked by DERIVED state.** `loadGraduatedFrom` reads the catalog's
  own `spec.graduated_from.deployed_system_id` stamp into a Map at folder open — the catalog row
  IS the record that graduation happened, so no new column. Loaded, not merely written: a Map
  only ever written is empty again after reload, which is the Bug #21 shape.
- **THE MANUAL FOLLOW-UP IS REQUIRED AND DOCUMENTED, NOT AUTOMATED.** A graduated engine is
  **unreachable by the matcher** until `KNOWN_ENGINE_KEYS` (index.html:1432) and the assessment
  roster (1445+) are hand-edited. `parseAssessResponse` throws on any `matched_engine` outside
  that hardcoded array, so no gap can name the new engine. Deriving the roster from the DB was
  considered and rejected: the DOES / NOT-FOR scope lines are hand-curated judgement that cannot
  be generated from a build step. The success message states this on screen.

### Live-test evidence — two real mistakes, both caught by verifying the DB rather than the UI

- **Attempt 1 produced NO write at all**, despite the UI appearing to succeed. API logs showed
  no POST to `/rest/v1/engine_catalog` and no filtered pre-check GET, proving execution bailed in
  a synchronous guard before any network call. RLS was ruled out (the `deployed_systems` POST
  returned 201 on the same session two minutes earlier). **The lesson is the method: the screen
  is not evidence.**
- **Attempt 2 wrote a row with the WRONG KEY AND NAME.** Position 7 ("Pipeline follow-up
  reminders") was graduated as `invoice_chase` / "Invoice Chase" — the identity of a different
  engine — and the scope line was the **unedited prefill**, byte-identical to the step's
  `spec_extras.purpose`, complete with a client anecdote ("four-month-old 'new' leads … in the
  spreadsheet") and no NOT-FOR clause. No code fault: prefill → edit → write behaved exactly as
  designed. **The human review step the design depends on simply did not happen.** Row deleted
  (nothing FK-references `engine_catalog`; verified before deleting) and re-graduated.
- **The same run exposed a REAL CONCURRENCY DEFECT, found only in the logs.** Three POSTs landed
  inside 50ms — one 201, two 409s. `busy:true` was set *after* the uniqueness pre-check's
  `await`, so the re-entry guard at the top of `confirmGraduate` was unarmed during that
  round-trip and a triple-click started three concurrent runs. **Only `UNIQUE(engine_key)`
  prevented a duplicate engine.** Fixed by moving the flag before the first `await`; the
  invariant is asserted as "no await precedes busy:true", not as a line position.
- **Attempt 3 verified clean**, and confirmed the fix under real use: one pre-check GET, one
  POST, **one 201, zero 409s**. Catalog 9→10, `formulated` 0→1, `spec.deployment` = `{tiers,
  spec_extras}`, `graduated_from.deployed_system_id` matching the position-7 ledger row,
  `isDeepEngine` true, scope text rewritten with three `never` clauses and no anecdote.
- A typo in the entered key (`pipline_follow_up`) was corrected by a scoped UPDATE rather than a
  third re-graduation — the row was otherwise right, and re-running risked losing good copy.
  `ENGINE_KEY_RE` validates shape, and shape cannot catch spelling.
- **80/80 harness assertions**, functions extracted from shipped source by brace-matching so the
  suite breaks rather than silently passing against a stale copy. Three harness bugs were found
  and fixed during the run (eval scoping, a truncated "real data" fixture, and a false positive
  from the word "await" appearing in a comment) — each failed loudly rather than passing wrongly.

### Follow-up captured, not built

- **The prefill warning is insufficient.** Attempt 2 proves an editable field with a
  rewrite-warning above it is not enough to guarantee the rewrite. Candidate responses, none
  chosen: reject a summary byte-identical to the prefill; start the field empty with the prefill
  offered behind an explicit "use build's purpose line" button; or require the operator to
  confirm the text differs. Deliberately NOT decided here — the failure has been seen exactly
  once, and the cheap mitigation (verifying the row afterwards) already caught it.
- Deepening an existing thin engine (shape b); an edit/un-graduate action (there is no undo —
  a wrong row needs manual SQL); deriving `KNOWN_ENGINE_KEYS` from the DB; cross-tab races,
  which no client-side flag can close and `UNIQUE(engine_key)` already handles.

## Order 16.6 — correction chat (Aug 19 2026)

A per-automation panel in the engine detail view. The operator describes a problem in
plain language; the agent reasons about it against the FULL stored engine plus a
mechanically-derived tag-flow hint, and proposes a confirm-gated edit to ONE automation.
`deriveTagFlow`/`tagFlowBlock`/`correctionsSinceDeploy`/`validateCorrectionProposal`/
`hardenCorrection`/`proposeCorrection`/`confirmCorrection`/`renderCorrectionPanel`,
`.corr-*`, index.html. **No migration.**
Map: `docs/planning/order_16_6_correction_chat.svg`/`.png`.

- **This makes an AI-designed workflow editable after generation.** `build_steps.workflow`
  was write-once at plan generation until now. Deliberate and governed, not an exception —
  confirmed as a permanent capability of the system.
- **REASONS ACROSS ALL AUTOMATIONS, WRITES TO EXACTLY ONE.** The core v1 decision.
  Cross-automation consequences are REPORTED in `ripples[]` for a human to act on, never
  auto-applied; a correction that silently edited a sibling would be the widest blast
  radius in the app.
- **Why no dependency model was built first.** Nothing in the codebase models node
  relationships: `config` is free prose, node `id` is stored but **read by nothing**
  (verified — every `.id ===` in the file is clients/gaps/plans), connectivity is array
  order plus branch nesting, the guard fork is synthesized at render from
  `config.split("→")`, and **no validator cross-checks the manifest against what the nodes
  actually do**. An explicit dependency schema was considered and REJECTED: it would have
  to be derived from the same prose, so it inherits the same imprecision with added false
  confidence, plus a migration and a backfill.
- **`deriveTagFlow` recovers the graph the data already implies.** The manifest supplies a
  CLOSED VOCABULARY, which makes matching it against config prose tractable rather than
  open-ended NLP. On real position 9 it recovers all three cross-automation tag edges.
  Fed to the AI as an explicitly APPROXIMATE hint whose failure modes the prompt names:
  templated variants (`'chase-active-{{invoice_id}}'` substring-matches `chase-active`
  while arguably being a different tag), and blindness to wait durations, the goal event,
  merge fields, and notification recipients. **Its "readers" are closer to REFERENCES than
  to reads-in-a-condition** — a purely descriptive prose mention in an `end` node counts.
  That is a known false-positive class, tolerable only because the hint is labelled and
  the drift it feeds is surfaced, never gating.
- **ONE derivation, not two.** Drift runs `deriveTagFlow` before and after and diffs,
  instead of reimplementing vocabulary matching inline. That preserves the write/read
  distinction a flat text diff loses — losing a tag's last WRITER while readers remain is
  a broken dependency; losing a reader usually is not — and keeps the drift check and the
  AI's hint provably consistent because they are the same traversal. Detecting NEWLY
  INVENTED tags is a genuinely different question and stays open extraction, because
  `deriveTagFlow` iterates the KNOWN vocabulary and is blind to an undeclared tag by
  construction. That extractor is a LABELLED HEURISTIC: it wants quoted hyphenated
  strings, so it misses other conventions (`appt_booked`) and can flag non-tags.
- **Validation chain:** `JSON.parse` → `validateCorrectionProposal` (shape, discriminated
  union) → **`validateNodes` + `validateAutomationTests` UNMODIFIED**, the same validators
  gating formulate → `hardenCorrection`. The last is correction-only and additive on
  purpose; folding it in would change formulate's behavior. It closes what the shared
  validators were never written to check, because they compare nothing against an
  ORIGINAL: **containment** (a proposal carrying a workflow array is rejected outright),
  **identity** (no rename, no trigger-type change — that makes it a different automation
  and would orphan the tests and the ledger), and **tag drift** (surfaced, never blocking;
  the manifest is NOT updated, because setup steps may already have run against the old one).
- **Discriminated union** — `propose` or `reply` — so refusing is first-class. A `reply`
  STOPS BEFORE the diff is computed, making an automation attached to a hedging reply
  unreachable by construction. Same doctrine as `proposeChatManifest`.
- **Locked to one open correction**, single-slot by construction. In-flight guards are
  IDENTITY-CHECKED: a late failure from automation A can no longer stamp its error, or
  clear `busy`, on automation B after the operator moved on. `busy:true` before the first
  await, per the Order 16.7 defect.
- **Ledger staleness is DERIVED.** `build_steps` has no `updated_at`, so the correction
  log's own timestamps are the clock — `correctionsSinceDeploy` compares `deployed_at`
  against them and the `deployed_systems` row renders "corrected since deploy · re-review".
  No column, same doctrine as `loadGraduatedFrom`.
- **The log lives at `deployment.corrections[]`** — no migration, and Order 16.7's
  graduation whitelist (`GRAD_DEPLOY_KEYS = tiers, spec_extras`) already excludes it BY
  DEFAULT, so a per-client correction history can never leak into a catalog template. That
  whitelist was written for exactly this case.
- **Placement** is `renderEngineDetail`'s Workflow card, below the node graph and Tests —
  the spot index.html reserved in a comment for "the future per-automation Refine /
  discuss chat". NOT `renderAutomationBody`, which renders node ROWS, not a graph.

### Live verification (Aug 19 2026) — what is PROVEN

A real correction on plan `de43a1b1` position 9, automation 0, via the preview deployment.
Request: *"the day-3 reminder still fires after the customer has paid"*.

- **The write.** `deployment.corrections[]` = 1 entry at `2026-08-19T15:17:48.226Z`,
  `automation_index: 0`, the operator's request stored verbatim, `nodes_before`/
  `nodes_after` both 23 (original preserved in full), `drift` empty in both fields,
  `changes_note` appended with the dated line.
- **Containment held.** Exactly `n9`, `n13`, `n17` changed to dual-condition guards;
  **`n2` unchanged** — correctly left alone, being the re-entry guard rather than a payment
  check. The sibling automation was not touched.
- **One clean PATCH.** `OPTIONS 200` then `PATCH 200` on
  `/rest/v1/build_steps?id=eq.ac05cd7f…&select=*`, 274ms apart. No retries, no duplicates,
  no errors. The busy-before-await guard held.
- **THE REASONING IS GENUINE, and this is the result that mattered** — the DoD warned that
  vacuous reasoning passing validation would be the thin-test bug class in a new place.
  Four specifics, all checkable in the stored log:
  1. It **cited the sibling's node `p5` by name** as the mechanism that clears
     `QB Invoice ID Being Chased`, and `p3` as the tag writer — it read the sibling, it did
     not gesture at it.
  2. It **diagnosed the actual mechanism rather than restating the symptom**: `n9`'s
     existing tag check looks sufficient on paper, but the tag is written by a DIFFERENT
     workflow, so polling/queue lag leaves it absent when `n9` evaluates. It also correctly
     noted the goal event only interrupts inside a Wait.
  3. It **extended the fix to `n13` and `n17` unprompted, with an explicit scope
     justification** — "this is not scope creep, it is the same fix applied to the same
     pattern" — having spotted the same latent vulnerability in nodes the operator never
     mentioned.
  4. Its ripple **named a real coupling its own change created**: CONDITION B depends on
     `p5` clearing the field to blank, so "if p5 is ever changed to write a placeholder
     value instead of clearing the field, the secondary guard condition silently stops
     working." It reported this while correctly concluding the sibling needed no edit.
- **61/61 harness assertions**, functions extracted from shipped source by brace-matching,
  against the REAL position-7 (5 automations) and position-9 (2 automations) rows. Two
  harness bugs found and fixed, both mine rather than the product's: the extractor took a
  default parameter's object literal as a function body and truncated `countNodeTypes` to
  its signature; and two assertions asserted the wrong outcome — stripping a tag from one
  automation does NOT lose its last reader, because the sibling's `end` node mentions it in
  prose, so the correct detection is `lost_cross_automation_link`.
- `lost_last_reader` / `lost_last_writer` are covered by a **SYNTHETIC fixture, labelled as
  such in the output** — neither can be produced from the real engines, where every declared
  tag is referenced in more than one automation.

**Correction to `6db6e8b`'s commit message.** That commit says `NOT VERIFIED LIVE`, which
was true when written and is now false. The write path, containment, the single clean
PATCH and the reasoning quality were all verified live on 2026-08-19, and the refusal path
was exercised afterwards. The message is left as-is rather than rewritten — history stays
honest about what was known at the time — and this paragraph is the correction of record.

### The refusal path — exercised, and it failed twice before it worked

Prompt: *"change the trigger so this fires on a schedule instead of the webhook"* on
position 9 automation 0 — a request `CORRECTION_CONTRACT_PROMPT` explicitly says must be
answered with `reply`. Three distinct outcomes across runs, each a different finding.

- **Two runs failed with "invalid JSON" on both the attempt and the retry.** The captured
  output shows why, and it is not a formatting fault: the model began a `propose`,
  reasoned its way INTO the violation, caught itself mid-`reasoning`, and — already
  committed to that shape — could not retract. It closed the object out with
  `"automation":{}`, wrote prose quoting the rule back at itself, then emitted a second,
  correct `{"action":"reply",...}`. TWO complete top-level objects; `JSON.parse` rejected
  the concatenation and discarded the correct answer sitting at the end of it. Fixed by
  `parseAiJson` (468e10b).
- **One run returned a complete, valid `propose` changing `trigger.type` to Scheduler**,
  reasoning that `never_touch` was about not regenerating an existing webhook URL rather
  than prohibiting a trigger change when explicitly asked. **This is the DoD's predicted
  failure mode — "a plausible correction to a request it should decline" — confirmed
  real.** `hardenCorrection` rejected it in `submitCorrection`, BEFORE the proposal was
  stored to state, so no review panel and no Apply button ever rendered. Verified against
  the database and the API logs: `workflow[0].trigger.type` is still `"Inbound Webhook"`,
  `corrections[]` is still 1 entry, and exactly one PATCH exists in the window — the
  earlier, unrelated correction. **Nothing was written.**
- **After the fixes, prompt 2 succeeded as a clean, well-reasoned refusal.**

**What that sequence proves, and it is the most important line in this section: identity
is enforced in CODE, not in the prompt.** The contract *told* the model to reply. It
didn't. The mechanical guard caught what the model's own judgement did not.

**And the successful refusal was still wrong about a fact.** Its reasoning asserted that
GHL has no native QuickBooks connector — false, and documented as false in this repo's own
`ghl-automation` skill. Right answer, wrong reason: the shape that passes every mechanical
check. See BUG_LEDGER #22.

### The in-scope control — passed

*"Make the day-14 escalation notify a different person"* produced a normal proposal with a
diff and an Apply button. This matters as much as the refusal: it confirms that four
commits of tightening did not produce over-refusal. A refusal here would have been a
regression, not a success.

### The ledger staleness chip — confirmed live Aug 29 2026

Observed rendering in production on the Tracker's Deployed card, for `de43a1b1`
position 9 (*Overdue invoices chase themselves until paid*):

    corrected since deploy (1) · re-review

Confirmed against the database, not read off the screen. `deployed_systems` row
`4a4d7931` points at build step `ac05cd7f` (position 9) with `deployed_at =
2026-08-11 23:55:16+00`. That step's `deployment->'corrections'` holds exactly ONE
entry, stamped `2026-08-19T15:17:48.226Z`, request *"the day-3 reminder still fires
after the customer has paid"*, `nodes_before` 23 → `nodes_after` 23 — the Aug 19
dual-condition-guard fix — and `corrected_at > deployed_at` evaluates true. So the
chip's `(1)` is the count the design intends, DERIVED at render from
`deployment.corrections[]` against `deployed_at`, with no `updated_at` column and
nothing persisted. That derived-not-stored property is the whole point, and it holds.

**The bullet this replaces was factually inverted, not merely stale.** It read:
"Position 9 is not in `deployed_systems`; position 7 is. Correcting position 7 would
exercise it." Position 9 has been in `deployed_systems` since 2026-08-11 23:55 — the
row the Aug 19 correction was logged against, and eight days before that line was
written. Both positions 7 and 9 were deployed that night, 49 minutes apart, and the
plan carries three deployed rows. So the chip was already exercisable on the very
engine being corrected, and no position-7 correction was ever needed; it was almost
certainly rendering on Aug 19 and simply was not looked at. The claim was wrong when
written — later work did not make it so. **"We did not check" and "it could not be
checked" are different failures, and this was the first.**

### Still not exercised

- **Which `parseAiJson` path the successful refusal took.** The function had no logging
  when that run happened, so a clean whole-string parse and a recovered two-object
  response were indistinguishable — both return silently. Logging was added afterwards
  (35f5ae3); the question is answerable on the next run, not retrospectively.
- **The moved-path indicator** in the rewritten diff. Both visual checks modified nodes in
  place, so `before_path` always equalled `after_path`. Covered by assertion, not by eye.

### The 300s ceiling — measured Aug 29 2026, and it is not a slow path

A turn-1 submission on `de43a1b1` position 9 automation 0 ("the day-3 reminder fires even
when the invoice was already partly paid") returned **504**. The Vercel dashboard shows the
function ran **4m50s (290s)** against `vercel.json`'s `maxDuration: 300`. The function was
killed at its ceiling — not a model failure, not a network fault between Vercel and the
browser.

**The framing that matters, and it corrects an earlier reading.** An earlier run of the
IDENTICAL prompt succeeded, so it completed under 300s. Wall-clock timings of ~7 minutes
recorded for that run included polling latency, not function duration. The two runs sit
within seconds of each other on opposite sides of the line. This is therefore **not a path
that is usually fast and occasionally slow — it runs at the ceiling every time, and
run-to-run variance decides the outcome.** A retry is a coin flip and always was.

**Where the time goes.** Measured on the live row, automation 0 of step `ac05cd7f`:

| component | chars | note |
|---|---|---|
| whole automation | 21,863 | 23 nodes |
| nodes WITH `deploy` | 14,096 | |
| nodes WITHOUT `deploy` | 5,397 | |
| **`deploy` buckets alone** | **8,699** | **62% of the node payload** |
| `tests` (12) | **6,343** | |
| sibling automation (read-only context) | 4,460 | 7 nodes |

`deploy` + `tests` = **15,042 of 21,863 chars — 69% of the emitted automation is verbatim
transcription of content the correction does not change.** The system prompt requires it:
"Return the COMPLETE corrected automation — every node, not a patch" and "Preserve every
node's existing deploy bucket". Turn 1's real change was TWO nodes; it paid ~7,000 output
tokens to copy 21 unchanged ones. Output generation dominates latency and input prefill is
cheap, so **the 42,704-byte request is not the problem — the response is.**

**Two things that look like fixes and are not.**

- **Streaming.** `api/ai.js` awaits `upstream.json()` in one shot, so adding streaming is the
  obvious reach. But `maxDuration` terminates the function whether or not bytes are flowing.
  Vercel's own streaming guidance concerns idle HTTP/1.1 connection drops — a different
  failure. Streaming would improve perceived latency; it would not have saved this request.
- **Lowering `max_tokens`** (the correction call passes 32000). It caps output, it does not
  accelerate generation. A lower cap converts a timeout into a truncation, which `ai()`
  already detects and throws on. Different error, same failure.

**Multi-turn does not compound this, contrary to the first reading.** Order 16.10's Option C
history grows the INPUT, and input is the cheap axis. Turn 2's output is the same shape as
turn 1's — one full automation re-emit — so turn 2 costs roughly what turn 1 costs.
Multi-turn sits at the same edge; it does not walk further off it.

**Plan ceilings** (Vercel, fluid compute): Hobby default 300s / max **300s** — no headroom,
already there. Pro and Enterprise default 300s / max **800s** generally available, 1800s in
per-function beta.

**The structural obstacle.** Emitting only changed nodes requires a stable key. Node `id` is
stored but READ BY NOTHING; connectivity is array order plus branch nesting. Merging by index
is unsafe precisely because corrections add and remove nodes — turn 1's proposal inserted
`n2a`. Merging by `id` would work but makes `id` load-bearing for the first time: a real
design change with its own failure modes, not a tuning tweak.

**Scoping note for a future DoD — the fix separates into two halves of very different
difficulty.** `tests` (6,343 chars) live in their own array, NOT positionally bound to nodes,
so preserving them unless a correction changes guard/condition count is comparatively simple
— and that alone is ~42% of the waste. `deploy` buckets (8,699 chars) are per-node and need
the stable key: the hard half. Solving only the cheap half captures most of the benefit.
Neither is scoped or approved; recorded so it is not rediscovered.

**The failure path itself behaved correctly, which nothing had exercised before.** The panel
rendered `.corr-err` — "The correction couldn't be produced: AI request failed: 504" — kept
the operator's composer text, never rendered an Apply button, and wrote nothing. A genuine
transport failure under a real infrastructure fault, handled without crashing, hanging on
"Thinking…", or synthesising an empty proposal.

### Follow-up fixes — four, all found by using the feature rather than by testing it

Each shipped as its own commit so it can be reverted independently.

**1 · Per-caller retry nudge (`f7ace34`).** `aiJsonWithRetry`'s retry instruction was
written for the propose contract and is wrong for any caller whose contract permits
refusing: on a violation it appended *"Respond with the complete corrected JSON only"* —
telling a model that had just declined to go produce the thing it declined. Fixed with an
optional `retryNudge` whose **default is the original string byte-identical**, so
formulate and parameterize are provably unchanged (asserted, not assumed). Correction and
setup chat pass their own, naming both shapes and stating that refusing is correct.

The setup-chat half is **INFERRED, NOT OBSERVED** — same shared function, same
`propose|reply` union, so the same defect should apply, but that path has never been seen
to fail this way. It writes to real GHL sub-accounts, which is why the inference was worth
acting on. The code comment says so in those words.

**This fix did not solve the reported failure.** The nudge only applies to attempt 2, and
attempt 1 was already unparseable. It was a real defect found while investigating a
different one.

**2 · `parseAiJson` (`468e10b`), and its observability (`35f5ae3`).** The actual cause of
the "invalid JSON" failures — two complete top-level objects in one response, from the
model self-correcting mid-generation. The whole-string `JSON.parse` is tried first and is
unchanged, so nothing that parses today can behave differently; only where we throw today
does the scan run, collecting balanced `{...}` regions and taking **the last that parses**.

Two details are load-bearing and both were caught only because the real capture was pasted
rather than reconstructed. **String tracking is scoped to inside a candidate object** —
between objects the model writes prose quoting its own rules back at itself, and a
globally-tracked string flag toggles on those prose quotes; an odd number of them would
silently swallow the following object. In the real capture the count happened to be even,
so the first draft would have worked **by luck**. And braces appear inside JSON string
values throughout this data (`{{contact.first_name}}`, `{{invoice_id}}`) because a
correction echoes node configs back verbatim, so a depth counter that ignores string
literals mis-balances on every one.

`35f5ae3` added the `console.info` on the fallback branch: without it a clean parse and a
recovered response were indistinguishable, and the question the fix exists to answer was
unanswerable.

**3 · Routing rules are not capability claims (`bea35f0`, BUG_LEDGER #22).** The refusal
was correct and its reasoning was factually wrong: it asserted GHL has no native
QuickBooks connector. `GHL_GRAMMAR_PROMPT` said *"QuickBooks and deep external-tool data =
n8n"* — correct **routing** guidance, which the model restated as a claim about what the
product lacks.

The nuance that would have blocked it exists in `.claude/skills/ghl-automation/SKILL.md`
(*"GHL's entire native QB integration is one automation: review-request after first invoice
paid"*) and **never reaches the model**: `grep -c "entire native QB integration"
index.html` returns 0. Skill files are read while BUILDING; runtime prompts are hand-written
summaries. **Every prompt is a lossy copy of curated documentation sitting one directory
away** — this repairs one line of that gap, it does not close it.

Two clauses added; the general one matters more than the QuickBooks one, because the same
conversion was available for every other external tool in that sentence. Routing is
unchanged. **NOT VERIFIED** — prompt behaviour cannot be regression-tested offline.

Separately, the panel's Reasoning box now carries a standing caution that claims about
GHL/n8n/third-party tools are the agent's judgement and have been wrong before. **Nothing
validates factual claims inside `reasoning`, and reasoning is the field the operator
trusts.**

**4 · `correctionDiff` rewrite (`cd06e4d`, BUG_LEDGER #23).** A correction inside a
condition's `yes`/`no` branch was **invisible** in the panel — the diff walked the top
level only, so the parent compared equal and rendered "unchanged". Never observed in
production; found by reading the code. Live rather than theoretical: 6 condition nodes
carry `yes`/`no` across the 195 top-level nodes in the three stored plans.

Rewritten with LCS anchors, same-type pairing between anchors, and branch recursion with
path descent. Scoped for Order 16.10's multi-turn work — the diff has to carry node
identity to be usable as model input — but shipped ahead of it as a standalone bug fix.

### Deferred, not dropped

Live GHL workflow reads (a read scope exists, but whether the payload carries node
structure is UNESTABLISHED — so drift against the real canvas is undetectable); sibling
writes; manifest updates; an undo button (`nodes_before` is logged, a revert is manual SQL);
correction of catalog engines; test-matrix regeneration.

## Order 16.10 — multi-turn correction chat (Sep 1 2026)

Order 16.6 shipped a correction panel that took ONE question and gave ONE answer. If the
proposal was wrong, or right but overscoped, the only moves were Apply or Discard. 16.10
makes the exchange a conversation: the operator can push back and the agent answers with
the earlier turn in view.

**Parts 3, 4, 5 and 8 are built. The button is labelled `Rephrase`, not "Refine"** — the
design discussions used "Refine" throughout and the shipped label is different; two render
sites (index.html:6514, :6562) both read `Rephrase` and both call `corrBack()`.

### What each part is

**Part 3 — `correctionDiffForModel(rows)`.** Serialises the diff the operator sees into
lines the model can read: `ADDED <path> (type): …`, `REMOVED …`, and `CHANGED <before_path>
-> <after_path> (type)` with BEFORE/AFTER on their own lines. A row flagged
`paired_by_position` carries its warning into the model's view verbatim — *"(paired by
position — this may not be the node you think it is)"* — so the agent inherits the same
uncertainty the panel shows a human. It returns EMPTY STRING when nothing changed, on
purpose: a "no changes" scaffold would read to the model as a turn that proposed something,
which is worse than saying nothing.

**Part 4 — history plumbing.** `chatHistoryForAi(messages)` takes the last 10 messages
EXCLUDING the current one (`slice(0,-1).slice(-10)`), drops any leading assistant turn so
the history always opens on a user message, and merges consecutive same-role turns. The
first line reads `Array.isArray(messages) ? messages : S.setup.chat.messages` — an explicit
type test, NOT `messages ||`, because an empty array is falsy-adjacent in the shape that
matters and a `||` would silently fall through to the Setup Agent's chat. `corrSay(role,
text)` appends `{role, text, at}` with the timestamp stamped at append time. `corrBack()`
guards on `busy`, sets `phase = "input"`, clears the composer and message, and re-renders —
**it does NOT clear the proposal**, which is what makes the next turn a continuation rather
than a restart.

**Part 5 — the log entry** gains `request` (the FIRST user message, falling back to the raw
composer text) and `exchange` (a copy of the whole message array), so an applied correction
records the conversation that produced it, not just the final ask.

### Option C: summary plus compact diff

Three history shapes were compared before building. Full echo of every prior proposal cost
~4,996 tokens/turn (~32.6k over a session, +328% on baseline). Summary-only was cheapest but
leaves the model unable to see its own prior proposal. **Option C — the summary line plus the
serialised diff — costs ~558 tokens/turn (~10.4k, +37%)** and is what shipped.

It works because of the RECONSTRUCTION PROPERTY: `userMsg` re-sends the stored automation in
full on every turn, so STORED + DIFF = the complete prior proposal. The history never has to
carry the proposal itself.

### The 300s ceiling had to be fixed first, and the fix is proven

The first live attempt died at the platform ceiling — see "The 300s ceiling" under Order
16.6. `vercel.json` went 300s → 800s in `96e9b93` (Pro allows 800s; Hobby would not have).

**Turn 1 then completed in ~317 seconds** — submitted 23:23:52Z, proposal present 23:29:09Z.
That is PAST the old 300s line, so the same run would have 504'd on the previous config. The
ceiling change is therefore proven decisive rather than merely coincident with a pass; a
completion at 280s would have proved nothing.

Turn 2 took ~95 seconds (00:06:12Z → 00:07:47Z) — roughly a third, because a `reply` emits
prose instead of a 29-node automation. **Reply turns are cheap; propose turns are not.**

### `parseAiJson`'s fallback is load-bearing, three for three

Every correction call that returned a parseable response has logged:

    parseAiJson: whole-string parse failed — recovered 1 top-level object(s), using the LAST.

Three of three — one in the Aug session, plus turn 1 and turn 2 here. **Note the count is
1, not 2**, so this is NOT the two-object self-correction that motivated `468e10b`; the
whole-string parse fails for some other reason and the balanced-brace scanner recovers it.
Without that commit every correction tonight would have surfaced as "invalid JSON". It is
not a defensive edge case — it is the normal path for this caller.

### Turn 1 — the proposal, and it was bigger than its predecessor

Prompt: *"the day-3 reminder fires even when the invoice was already partly paid"* on
`de43a1b1` position 9 automation 0.

Diagnosis, and it is correct: `invoice-paid` and the `QB Invoice ID Being Chased` field are
BOTH written only by the sibling, which fires on `invoice.paid`; a partial payment leaves QB
status Unpaid, so neither signal is ever set and every guard passes.

The fix it proposed builds an n8n round-trip INTO the workflow: three outbound webhooks to a
QB-balance-check endpoint, three 2-minute waits for the round trip, and a CONDITION C
(`QB Invoice Amount Due = 0 → end`) on all three guards. **Node count 23 → 29.**

**An earlier run of the identical prompt reached the same diagnosis and stopped far short** —
it fixed only the stale amount and routed the stop-the-chase question to a ripple as an
operator decision. Same finding, very different blast radius, and the divergence is invisible
from the diff alone. Worth knowing that this feature's output varies in ambition run to run.

The moved-path indicator — the third item on Order 16.6's "Still not exercised" list —
**is now exercised**: `changed #9 → #8`, `#12 → #16`, `#17 → #20` all rendered correctly.

### Turn 2 — the proof that history threads

Prompt: the n8n endpoint does not exist and is not being built; scope back to the stale
amount; record the balance-check as a ripple.

The agent returned a **`reply`, not a `propose`**, and declined even the narrowed request —
correctly. `QB Invoice Amount Due` is written once at `n3` and read at message time; with the
webhook-out ruled out, **no node change inside this automation can make a once-written field
fresher.** Editing message copy would have been theatre. It moved the fix to n8n, where the
data originates.

**The sentence that proves history threading:**

> "The balance-check webhook-out approach would have solved this by asking n8n to refresh the
> field before each message, but the operator has ruled that out."

That is unwritable without sight of turn 1. The phrase "webhook-out approach" appears nowhere
in the turn-2 prompt, and nothing in stored state mentions webhook-outs because turn 1 was
never applied. `chatHistoryForAi` + `correctionDiffForModel` genuinely carried the prior turn
forward. **This was the one open question 143 assertions could not answer, and the answer is
yes.**

The panel rendered `corr-reply` with the header *"The agent did not propose a change"*,
`diffRowCount: 0`, `rippleCount: 0`, and **no Apply button in the DOM** — the discriminated
union stopping before the diff, on a second and unrelated occasion.

### Known gap — `ripples[]` is unreachable on a reply turn

The operator asked for the balance-check idea to be "recorded as a ripple". **It could not
be.** A `reply` carries no `ripples[]` array by construction — the union stops before ripples
are computed — so the idea survives only as prose inside the reply text, not as structured
data anything can later read.

That is a real limitation, not an oversight in the run: a request to "log this for later" has
no home in the reply shape. Whether reply turns should be able to emit ripples is UNDECIDED
after one occurrence and deliberately not designed here.

### Still unexercised after 16.10

- A THIRD turn. Both live sessions stopped at two.
- `paired_by_position` reaching the model. No turn has produced a mis-paired row, so the
  warning line has never actually been transmitted.
- An applied multi-turn correction. `Apply` was never pressed, so `exchange` has never been
  written to `deployment.corrections[]` in production.
