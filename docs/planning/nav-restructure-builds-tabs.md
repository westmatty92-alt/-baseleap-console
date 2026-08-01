# Navigation Restructure — "Builds" with per-folder tabs, folder-scoped scope, delete/archive

Status: **PLAN — awaiting approval, no code yet.** Author: session 2026-07-18.
Visual map: `docs/planning/nav_restructure_builds_tabs.svg` / `.png`.

Separate from the deferred System Composer discovery-flow work (Order 15.99 — stays logged, not started).

---

## 1. What changes (scope)

1. Rename left-nav **"Automation agent" → "Builds."**
2. Remove the global **Feasibility / Finalize / Build plan** subtabs (they currently sit above the folder grid at the module level).
3. Remove **"Gap report"** and **"Proposal"** as separate left-nav items.
4. Move **all five** surfaces to live as **tabs inside each individual build folder**, confirmed order:
   **Feasibility → Gap Report → Finalize → Build Plan → Proposal.**
5. Add a **delete** control inside an open build folder (not on the grid card), with a `setup_runs`-aware **archive fallback**.

---

## 2. Load-bearing findings this plan is built on (traced 2026-07-18)

- `gaps` are **client-level**: loaded by `.from("gaps").eq("client_id", clientId)`; **no `build_plan_id` column** exists. `gaps.selection` (`proposed|accepted|declined`) is a single client-level field per gap.
- The planner reads accepted gaps at generation via `loadAcceptedGaps(clientId)` — **client scope, not plan scope.**
- **Gap Report and Proposal are unbuilt** — `render()` falls through to the generic "module will be built next" placeholder; `S.report = null`, `S.proposal = null`; no `gap_reports`/`proposals` reads/writes; those tables are base-schema stubs not even in `/migrations`.
- Only `build_steps.build_plan_id` (**ON DELETE CASCADE**) and `setup_runs.build_plan_id` (**default NO ACTION → RESTRICT-like**) carry a plan FK. `setup_runs` **are** stamped with `build_plan_id` on every Setup Agent run (`runGhlSetup`).

## 3. Decisions locked (with the user, this session)

| # | Decision | Chosen |
|---|---|---|
| D1 | Data ownership | **Hybrid**, refined: Feasibility client-level/shared; **Finalize, Gap Report, Build Plan, Proposal all folder-scoped.** |
| D2 | Creation flow | **Flow 2** — keep today's draft-then-save; gap selection persists to `build_plan_gaps` **on save** (no empty pre-created folders; "nothing written until save" preserved). |
| D3 | Finalize behavior | **Bimodal** — active picker pre-save; **read-only "Scope locked" record post-save.** Re-scoping = start a new build (append-only). |
| D4 | Gap Report / Proposal | Built **fresh**, **folder-scoped**, from the folder's **frozen** `build_plan_gaps`. Regenerable as a *document* without changing scope. |
| D5 | Delete | **Block + archive fallback**: 0 `setup_runs` → verified hard-delete (steps cascade); ≥1 → block + archive via `build_plans.status`. Never delete `setup_runs`. |

**The organizing principle:** *Feasibility is the shared, reusable gap-qualification layer. Everything downstream of "which gaps are in this build" is folder-scoped and frozen with the saved build.*

---

## 4. Information architecture — before → after

### Left nav
```
BEFORE                          AFTER
  Client research                 Client research
  Audit assistant                 Audit assistant
  Automation agent   ─┐           Builds            ← renamed
  Gap report          │ removed   Setup agent
  Proposal            │ as nav
  Setup agent        ─┘ items
```
Gap report + Proposal are no longer nav items; they become tabs inside a folder.

### Builds module
```
Builds
 ├─ Folder GRID  (unchanged: one card per build_plans row + "New build")
 └─ OPEN FOLDER  → tabbed shell:
        [ Feasibility ] [ Gap Report ] [ Finalize ] [ Build Plan ] [ Proposal ]
             client         folder        folder        folder        folder
             shared        frozen        bimodal       committed      frozen
```

The current module-level subtabs `[["gaps","Feasibility"],["finalize","Finalize"],["plan","Build plan"]]` (line ~2060) are **deleted**; the tab bar moves *inside* the open-folder view. The grid itself (`renderBuildFolderGrid`) is unchanged.

---

## 5. The tab shell — one shell, two modes (Flow 2)

The 5-tab shell renders for a build in **both** states, so Finalize appears as a peer tab during the one moment it's actionable, while nothing is persisted until Save.

### Mode A — UNSAVED (creating a new build; `S.buildPlan.draft` set, no `build_plans` row)
- **Feasibility** — client-level picker/qualify (relocated `renderFeasibilityBody`); read-mostly here.
- **Gap Report** — preview built from the *current draft selection* (not yet frozen).
- **Finalize** — **ACTIVE**: accept/decline/reset gaps for *this build*; writes to the draft's per-build selection (not client `gaps.selection`).
- **Build Plan** — Generate + draft review (`renderDraftReview`).
- **Proposal** — preview from the draft selection.
- **Save** commits atomically: `build_plans` row + `build_steps` + **`build_plan_gaps`** (the frozen scope).

> Preserves D2's "nothing written until save": the shell is UI; the row appears only on Save. No empty folders in the grid.

### Mode B — SAVED (open folder; `S.buildPlan.activePlanId` set, no draft)
- **Feasibility** — same client-level view (shared across folders; a visual "client-scoped" cue distinguishes it from the frozen tabs).
- **Gap Report** — folder-scoped **document** generated from this folder's `build_plan_gaps`; regenerable as a doc, scope frozen.
- **Finalize** — **"Scope locked"** read-only record (§7).
- **Build Plan** — committed steps (`renderSavedPlan`).
- **Proposal** — folder-scoped document from the frozen scope; regenerable as a doc, scope frozen.

Render precedence extends today's `draft ? … : activePlanId ? … : grid` — the draft and saved branches each now render the tab shell; the active tab lives in new state `S.buildPlan.tab` (default `"plan"` so existing muscle-memory lands on Build Plan).

---

## 6. Schema — migration 012: `build_plan_gaps`

Per-folder gap selection (replaces reliance on the client-level `gaps.selection` for build scope). Same RLS/`operator_id` pattern as 005/010.

```sql
-- 012: per-build gap scope (folder-scoped Finalize). Run manually in Supabase SQL editor.
CREATE TABLE IF NOT EXISTS build_plan_gaps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  build_plan_id UUID NOT NULL REFERENCES build_plans(id) ON DELETE CASCADE,
  gap_id        UUID NOT NULL REFERENCES gaps(id),          -- NO cascade: a build's scope record
                                                            -- survives a client-pool gap edit; display
                                                            -- degrades gracefully if the gap is gone.
  operator_id   UUID NOT NULL,
  selection     TEXT NOT NULL DEFAULT 'accepted'
                  CHECK (selection IN ('accepted','declined')),  -- only decided gaps are persisted per build
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (build_plan_id, gap_id)
);
ALTER TABLE build_plan_gaps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS build_plan_gaps_operator ON build_plan_gaps;
CREATE POLICY build_plan_gaps_operator ON build_plan_gaps
  FOR ALL USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
```

Notes:
- `build_plan_id` **CASCADE** (a deleted build's scope rows go with it, like `build_steps`); `gap_id` **no cascade** (the folder's frozen record must outlive client-pool edits — the locked list degrades to "— gap no longer in catalog" rather than blanking).
- **`gaps.selection` is retained but goes dormant** — left in place for back-compat (existing clients' data untouched); build scope now reads `build_plan_gaps`. Not dropped in 012 (additive-only; a later cleanup migration can retire it once nothing reads it).
- A build always saves ≥1 `accepted` row (draft can't commit an empty scope), so a saved folder always has a real frozen scope.
- Same gap MAY appear in two folders' `build_plan_gaps` (a gap buildable across engagements) — intended; the `UNIQUE` is per `(plan, gap)`, not per gap.

---

## 7. Bimodal Finalize — the locked-state design (D3, approved)

**Pre-save (active):** unchanged in spirit from `renderFinalizeBody` — the accept / decline / reset bulk bar + interactive gap cards — but writing to the draft's per-build selection instead of client `gaps.selection`.

**Post-save ("Scope locked"):**
```
┌──────────────────────────────────────────────────────────────┐
│  🔒  Scope locked                                     (Volt) │
│  This build's scope was set when it was generated and is      │
│  frozen — a saved build is an immutable record. To change     │
│  which gaps are included, start a new build.                  │
│        [ + Start a new build to re-scope ]           (Volt)   │
├──────────────────────────────────────────────────────────────┤
│  Included in this build · 3 gaps · 14h                        │
│   ✓  Missed-call text-back            simple · 3h             │
│   ✓  Review request engine            simple · 4h             │
│   ✓  Payment failure recovery         complex · 7h            │
└──────────────────────────────────────────────────────────────┘
```
Four signals it reads as *designed*, not dead: (1) Volt-tinted lock banner with a heading (not grey/disabled), (2) one sentence naming the *why* (immutable record) so the absent buttons are explained, (3) a prominent **enabled** primary CTA (`+ Start a new build to re-scope` → `startNewBuild()`), (4) read-only ✓ rows with the accept/decline bar entirely absent — the contrast to the active surface distinguishes the modes at a glance.
- **Pre-seed the re-scope**: the new draft opens with this folder's included gaps pre-selected (clone-and-adjust, not cold start).
- **Robust to client-level drift**: list reads this folder's `build_plan_gaps` (joined to `gaps` for display); a since-deleted gap renders "— gap no longer in catalog."

---

## 8. Gap Report & Proposal — built fresh, folder-scoped, frozen (D4)

Both are new modules (today: placeholders). Both are **folder-scoped documents** generated from the folder's **frozen** `build_plan_gaps`:
- **Gap Report** — client-facing report of *this build's* gaps (title/problem/cost/severity per gap). Generated on demand; **regenerable as a document** (re-run the copy) **without changing scope**. Scope changing still = a new build.
- **Proposal** — scoped proposal for *this build's* work, built from its Gap Report + a package. Same frozen-scope / regenerable-document rule.
- Persistence: each is its own per-`build_plan` artifact (new tables `gap_reports` / `proposals` gain `build_plan_id`; exact columns designed when these modules are built — this plan establishes **scope binding**, not their full column set).
- In Mode A (unsaved), both render as **previews** off the draft selection; they become frozen documents once the build is saved.

> This plan wires the **tab placement + scope binding** for Gap Report/Proposal. Their full generation/copy design is a follow-on build per module (kept out of scope here to avoid designing past the data model).

---

## 9. Delete + archive (D5)

Control lives **inside an open folder** (Build Plan tab header area), never on a grid card.

```
onDelete(planId):
  runs = count(setup_runs where build_plan_id = planId)
  if runs == 0:
     confirm → sb.from("build_plans").delete().eq("id",planId).select()   ← verify returned row
     (build_steps + build_plan_gaps cascade)  →  close folder, re-render grid
  if runs >= 1:
     BLOCK. Show: "This build has N setup run(s) recorded — its provisioning
     history can't be safely deleted. Archive it instead."
     offer → sb.from("build_plans").update({status:'archived'}).eq("id",planId).select().single()
     (grid gains an archived filter; archived folders hidden by default)
```
- `setup_runs` is **never** deleted — it's the audit trail the RESTRICT protects (CLAUDE.md: "Archive with status; don't hard-delete").
- Delete/update both **`.select()`-verify** the returned row (CLAUDE.md write-verify rule); a bare `.delete()`/`.update()` can report false success.
- `build_plan_gaps` cascades with the plan on the 0-run hard-delete path (§6).
- Existing `rollbackBuildPlan` (0-run path) already proves the cascade delete works.

---

## 10. State & function impact (index.html)

- `MODULES`: rename `automation` title → "Builds"; drop `report` + `proposal` module entries (or leave as dead keys — **remove** to keep the nav honest).
- Nav markup (lines 376–381): rename button, delete the `report` + `proposal` `<button>`s.
- `freshBuildPlan()`: add `tab:"plan"` (active in-folder tab). `freshAutomation()` stays for the client-level Feasibility pool (or merges — decide at build).
- `renderAutomation` → `renderBuilds`: emits the grid **or** the open-folder **tab shell**; delegates to per-tab bodies.
- Relocate `renderFeasibilityBody` (client-level) + `renderFinalizeBody` (now bimodal, draft-selection target) into tab bodies.
- New: `renderGapReportTab`, `renderProposalTab`, `renderScopeLocked`, `deleteBuild`, `archiveBuild`, `build_plan_gaps` read/write in `saveBuildPlan` + `loadAcceptedGaps` (now folder-scoped from the draft).
- `resetClientState`: unchanged (still wipes per-client module state on switch).

---

## 11. Definition of Done

1. Nav shows **Builds** (not Automation agent); **Gap report** and **Proposal** nav items are gone; no dead module placeholders reachable.
2. The global Feasibility/Finalize/Build-plan subtabs are gone; opening a folder shows the 5-tab shell in the confirmed order.
3. Migration 012 `build_plan_gaps` created (RLS verified); a saved build persists its accepted gaps there; `saveBuildPlan` writes plan + steps + scope atomically (rollback verified on partial failure).
4. **Finalize is bimodal**: active picker pre-save; **"Scope locked"** record post-save with the approved banner + enabled re-scope CTA (pre-seeded) + graceful drift handling.
5. Feasibility renders client-level/shared (same across folders, with a client-scoped cue); Gap Report/Proposal render folder-scoped off the frozen scope (preview pre-save, document post-save), regenerable as documents without scope change.
6. Delete inside an open folder: 0 runs → verified hard-delete + cascade + grid refresh; ≥1 run → blocked with explanation + archive-via-status; `setup_runs` never touched; all writes `.select()`-verified.
7. Client switch bleeds nothing (resetClientState covers new state).
8. In-repo guide (`MASTER_BUILD_GUIDE.md` / data contracts) + Console Operator SOP updated for the new IA in the same session.

---

## 12. Sequencing (suggested build order — each its own review)

1. **Migration 012** (schema first; run manually, verify live).
2. **Nav rename + subtab removal + tab shell scaffold** (structural; grid untouched).
3. **Finalize → folder-scoped + `build_plan_gaps` wiring** in save/generate (bimodal active side).
4. **Scope-locked post-save state** (§7).
5. **Delete + archive** (§9).
6. **Gap Report / Proposal** tab placement + scope binding (documents = follow-on per module).

Out of scope here: full Gap Report/Proposal generation/copy design; retiring `gaps.selection`; System Composer (Order 15.99).
