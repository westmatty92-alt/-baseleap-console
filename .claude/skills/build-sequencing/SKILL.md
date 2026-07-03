# build-sequencing

## What it is
The dependency-ordering doctrine for the build-planner: how validated, accepted gaps
plus their setup prerequisites become ONE dependency-ordered plan of build_steps.
Consumed at plan generation (and revision) time, alongside automation-catalog
(engines), ghl-setup (foundation gates), and — Mode 2 only — ghl-automation (grammar).

## When to use it
Read whenever generating or reordering a build plan (Automation Agent Phase C).

## Ordering rules (in priority order)
1. **Long-lead first, always.** A2P registration and domain/email-auth verification
   have external approval clocks and gate whole channels. If any accepted engine
   sends SMS → the A2P step is position 1 regardless of that engine's own priority.
   Same for email auth + warm-up (a fresh sub-account cannot bulk-send day one).
2. **Foundation before engines, scoped per engine.** An engine waits only on the
   gates it actually needs — never block a no-SMS engine on A2P. Derive each
   engine's gates from ghl-setup's hard dependency rules (fields → forms →
   workflows; domain → funnel/email; host user → calendar; pipeline + duplicate
   policy → opportunity workflows).
3. **Catalog dependency order.** Payment Processor Foundation → payment-triggered
   engines (booking Won-state, session decrement, referral revenue awards) →
   loyalty/membership on top. Flag any accepted gap needing a prerequisite engine
   that was NOT accepted — that's a scope hole to surface, not silently absorb.
4. **Dedupe foundations.** One A2P step, one email-auth step, one pipeline step —
   each with many dependents. Never emit a per-engine copy of a shared gate.
5. **Value × effort fills the slack.** Where dependencies leave free ordering,
   sequence quick wins first (high severity / low estimated_hours) — early visible
   wins for the client. Dependencies always outrank value ordering.
6. **Every engine ends with a test-gate step.** Configured ≠ complete: the last
   step of each engine's chain is its controlled test (checklist = the test
   matrix items). The engine is not "done" until the test step is done.
7. **Parallel tracks are fine.** Independent dependency subtrees don't need
   artificial ordering between them; position numbers interleave them freely.

## Cross-agent edges
A step from either agent may depend on a step from the other. Typical direction:
automation depends on setup (Review Engine workflow ← GBP connected ← A2P).
Reverse exists too (a setup step that imports data can wait on an automation
step that cleans it). Edges are step-id references — agent is an attribute,
not a partition.

## The step contract (what generation must emit)
JSON: { steps: [ { ref, agent: "setup"|"automation", mode: "deploy"|"design"|null,
gap_ref: <index into supplied gaps or null>, title, detail, checklist: [strings],
estimated_hours, depends_on: [refs] } ] }
- `ref` is a local string id; resolved to real UUIDs on save.
- `title` is CLIENT-SAFE plain language ("Automated review requests go live") —
  all mechanics, tool names, and wiring go in `detail`. Never hours/price in title.
- Validation before save (defensive, client-side): shape-check every field,
  every depends_on ref must exist, graph must be acyclic. Reject and retry once
  on failure; never save an invalid graph.

## Deterministic ordering (code, not AI)
Topological sort of the validated graph assigns `position`. Tiebreak within
same depth: long-lead flags → severity → ascending estimated_hours. The AI
proposes edges; the CODE orders them — never trust model-emitted positions.
