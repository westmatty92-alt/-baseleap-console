# Order 16 — Deployed-system ledger (v1)

Status: **APPROVED 2026-08-05 — building to this DoD.** Author: session 2026-08-05.
Visual map: `docs/planning/order_16_deployed_systems_ledger.svg` / `.png`.

Scope decisions were taken from the Aug 5 investigation report and approved in that form:
one table, engine-grain, snapshot-plus-pointer, decoupled from the `done` click, **no** SOP
generation and **no** automatic catalog graduation. §6 (delete-guard extension) approved with it.

---

## 1. The problem this solves

Nothing in the console records that a system is **live in a client's account**.

- `clients.ghl_map` records that an *asset* exists (14 ids on `123 business`) but is flat and
  client-level — it cannot attribute an asset to an engine or to a build.
- `setup_runs` records that a *provisioning run* happened, with real per-item provenance, but
  covers only the five mechanical kinds (tags, fields, custom values, calendars, pipelines).
- **Workflows are not among those five.** The engines — the actual deliverable — are hand-built
  in GHL. No machine record anywhere says "engine X is live for client Y."

So the ledger's core content is necessarily an **operator assertion**, not a derivation. v1 is
built to make that assertion explicit, cheap, and durable. Anything that pretends the ledger is
derived would be lying about its own provenance.

## 2. Load-bearing findings this plan is built on (traced 2026-08-05, live DB + shipped source)

- `build_steps` already carries the full as-built spec per build: `manifest`, `workflow`,
  `deployment` are all non-null on all four engine steps of plan `de43a1b1`. The ledger does
  **not** need to re-author or duplicate a spec.
- `build_steps.completed_at` is stamped on `done` and cleared on any move away
  (`setStepStatus`, `index.html:5481`); its own comment calls it "the Phase D hinge (SOP-gen +
  ledger)". Order 15 gave it its first read site.
- `engine_catalog.status` carries the live CHECK `proven | documented | formulated` — already
  a graduation ladder. Live rows: 3 `proven`, 6 `documented`, 0 `formulated`.
- The graduation loop is **open by explicit design**: `formulateEngine` is commented "Never
  written to `engine_catalog` here; graduation is the operator's call after a real build
  (separate step, deferred)", and the automation-catalog skill says "The Agent proposes; the
  operator confirms what graduates. Never auto-write — the catalog is also the price sheet."
  The only writes today are two hand-run browser-console functions (`upsertReviewEngine`,
  `updateEngineManifest`).
- Deleting `build_plans` **cascades** to `build_steps`. `setup_runs.build_plan_id` is
  RESTRICT-like and the open-folder delete already counts runs to choose block-and-archive over
  hard delete.
- `clients.status` and `build_plans.status` have **no CHECK constraint** — both free text.
  The ledger introduces no new lifecycle vocabulary on either.
- **The engine predicate:** `categorizeSteps().engines` deliberately includes unmatched test
  gates (it is a render slot, not a truth claim). The workflow-carrying test is what
  `partitionTestGates` already uses to identify an engine parent (`index.html:5063-5064`).

## 3. Data state at plan time — and what it means for verification

| | |
|---|---|
| clients | 3 — only `123 business` has a GHL connection, token, `paid_at`, `ghl_map` |
| build_plans | 3, all on that one client (1 archived, 2 draft) |
| setup_runs | 3 — one on the archived plan, two with `build_plan_id: null` (Aug 3/4 chat tests) |
| build_steps `done` | 4, all on plan `de43a1b1`, `completed_at` spanning **7 seconds** on 2026-07-24 |

Four completions inside seven seconds is a click-through, not a build week. **There is no real
deployed system in the database.** A live test therefore proves the mechanism (write reaches
the DB, returns its row, renders, survives reload) and *not* that a real engine shipped. This
is stated in the DoD rather than discovered at verification time.

## 4. Decisions locked

| # | Decision | Chosen |
|---|---|---|
| 1 | Entry grain | **One deployed engine per client.** Matches the gap ≈ engine ≈ sellable-unit grain used app-wide. |
| 2 | Identity under plan delete | **Snapshot + nullable pointer.** Title/engine_key/mode copied at write; FKs `ON DELETE SET NULL`. Row survives a plan delete with its identity intact. |
| 3 | Re-deployment / supersession | **Deferred, not designed-around.** No `superseded_by` column in v1 — re-deploy semantics are unresolved and doctrine already makes an add-on a NEW plan. A partial `UNIQUE(build_step_id)` prevents double-marking the same step. |
| 4 | Trigger | **Explicit "Mark deployed" action, not the `done` click.** Marking a step done is a PM act; asserting a system is live in a client's account is a different claim with external consequences. |
| 5 | SOP generation | **Out of v1.** No substrate, and the three audiences are undefined anywhere in the repo. |
| 6 | Catalog graduation | **Read-only hint only.** v1 labels a `formulate`-mode entry graduation-eligible; it never writes `engine_catalog`. Preserves the "operator confirms what graduates / never auto-write" doctrine. |
| 7 | Client-level cross-plan map | **Out of v1.** That is the surface anticipated at `index.html:4122`; it reads the ledger and is its own increment. |
| 8 | Delete guard (§6, approved) | The open-folder delete counts `deployed_systems` **as well as** `setup_runs`; a plan with a live engine archives instead of hard-deleting. |

## 5. Definition of Done

### 5.1 Schema — `migrations/014_deployed_systems.sql`

```sql
CREATE TABLE IF NOT EXISTS deployed_systems (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id    UUID NOT NULL,
  client_id      UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  build_plan_id  UUID REFERENCES build_plans(id) ON DELETE SET NULL,
  build_step_id  UUID REFERENCES build_steps(id) ON DELETE SET NULL,
  title          TEXT NOT NULL,          -- snapshot: the engine step's title at deploy time
  engine_key     TEXT,                   -- snapshot of matched_engine; NULL for a formulate engine
  mode           TEXT CHECK (mode IN ('retrieve','formulate')),  -- snapshot; what graduation reads
  deployed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS deployed_systems_step_uniq
  ON deployed_systems (build_step_id) WHERE build_step_id IS NOT NULL;

ALTER TABLE deployed_systems ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS deployed_systems_operator ON deployed_systems;
CREATE POLICY deployed_systems_operator ON deployed_systems
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
```

Run manually in the Supabase SQL editor (schema changes are never wired to GitHub). Table count
moves eleven → twelve.

**Done when:** the migration file exists, has been run live, and `information_schema` +
`pg_constraint` confirm every column, the CHECK, the partial unique index, and RLS enabled.

### 5.2 Eligibility — one definition, reusing the existing notion

```js
// A deployed system is an ENGINE: an automation step that carries a real workflow.
// NOT categorizeSteps().engines — that deliberately includes unmatched test gates
// because it is a render slot. The workflow test is the same one partitionTestGates
// uses to identify an engine parent, so the two can never disagree about what an engine is.
function isDeployableEngine(s){
  return s.agent === "automation" && Array.isArray(s.workflow) && s.workflow.length > 0;
}
```

**Done when:** the predicate selects exactly the four engine steps (positions 7, 9, 12, 15) on
plan `de43a1b1` and zero setup steps and zero test gates, asserted in the harness.

### 5.3 Write path

- `markDeployed(stepId)` — confirm gate first (states the client and the engine by name), then
  INSERT stamping `operator_id: S.user.id`, snapshotting `title` / `engine_key` (from
  `matched_engine`) / `mode`, and pointing at `build_step_id` + `build_plan_id`.
- **`.select().single()`-verified**, and the local ledger array is re-rendered from the returned
  row — never from the optimistic object.
- Guarded on `s.status === "done"` **and** `isDeployableEngine(s)`. A non-done or non-engine step
  has no control rendered and the function rejects it if called anyway.
- Duplicate insert (partial unique index violation) surfaces as a plain message, not a crash.
- `removeDeployedSystem(id)` — the one mutation, confirm-gated, `.select()`-verified. A
  mis-assertion must be correctable; this is documented as the deliberate exception to
  append-only.

**Done when:** happy path, duplicate-insert rejection, non-engine rejection, and non-done
rejection are each exercised and reported with their actual output.

### 5.4 Read path / render

- Ledger loaded per client alongside the existing build-plan load, into `S.buildPlan.deployed`
  (declared in `freshBuildPlan()` so `resetClientState()` clears it on client switch).
- **Tracker gains a "Deployed" card** listing this plan's entries: title, `deployed_at`,
  `retrieve|formulate`, and — on formulate entries only — a read-only
  **"graduation-eligible"** label. Empty state renders "Nothing deployed yet."
- **Done-bucket rows** gain either a `Mark deployed` button (engine, not yet ledgered) or a
  `Deployed · <date>` pill (already ledgered). No other bucket renders either.
- The four Tracker buckets and the header total are **untouched** — the ledger adds a card and
  a row control, and changes no bucket arithmetic.

**Done when:** the Tracker's four buckets still re-sum to `steps.length` with the ledger card
present, verified on the real 17-step plan.

### 5.5 Delete guard (§6, approved)

The open-folder delete currently counts `setup_runs` to choose block-and-archive over hard
delete. It now counts `deployed_systems` as well: a plan with **either** a provisioning run or a
ledgered live engine archives instead of hard-deleting.

With `ON DELETE SET NULL` the ledger row survives either way — this protects the *pointer*, not
the record. The blocked-delete explanation names which of the two conditions applied (or both),
so the operator is never told "there are runs" when the real reason is a live engine.

**Done when:** a plan with 0 runs + 0 deployed still hard-deletes; a plan with 0 runs + ≥1
deployed blocks and archives; the message names the actual reason. Exercised live.

### 5.6 Non-goals, stated so a later session doesn't assume them

No SOP generation. No `engine_catalog` write of any kind. No client-level cross-plan map. No
change to `setStepStatus()`. No change to `build_plans.status` or `clients.status`. No change to
`renderEngineRow` (its blocked-by-on-done cosmetic issue stays a separate candidate).

### 5.7 Docs

`CLAUDE.md` DATA CONTRACTS gains a `deployed_systems` bullet; `MASTER_BUILD_GUIDE.md` gains an
"Order 16 — deployed-system ledger" section. Console Operator SOP text is **drafted in the
response for Matthew to paste** — never written by Claude.
