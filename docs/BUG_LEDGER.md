# BUG LEDGER — Baseleap Console

Numbered incidents and the lesson each one bought. Numbering continues the bug
history in the Notion Console spec; entries land here when the lesson should sit
next to the code. Newest first.

## Bug #19 — retrieve-vs-create failure: nearest-sounding engine matched instead of judged (July 5 2026)

**Symptom:** on the 123 Business plan, (a) "Manual invoice creation /
invoice-milestone sequences" (a QuickBooks invoicing workflow) confidently
RETRIEVED `payments_stripe` — a payment-PROCESSING engine that does no
invoicing; (b) "No-show re-engagement" and "missed call text-back" matched thin
catalog stubs (no `spec.manifest`, no real workflow) and retrieved EMPTY step
bodies flagged "⚠ tags/fields TBD, build manually."

**Root cause:** two holes behind one behavior — the assessment answered "which
engine is closest?" instead of "does an engine actually do this job?".
(1) Scope hole: the prompt said "match to a known engine where possible", null
was only a fallback clause, and catalog lines carried name+band with no
boundaries — so an invoicing gap latched onto the nearest payment-sounding key.
(2) Depth hole: `classifyGapRoute` never consulted engine depth; any stub with
`client_parameters` routed "parameterize" and shipped an empty retrieve.

**Fix (`same session`):** layered gate. In DATA: `isDeepEngine` depth guard in
`classifyGapRoute` — retrieve requires the live row to carry `spec.manifest` AND
real workflow content; anything less routes to formulate SEEDED with the stub
(`catalogSeedBlock`: summary/pattern/manifest/deployment/knobs as constraints),
`engine_key` stays null, `seeded_from` persists on `build_steps.deployment`. In
PROMPT: retrieve-vs-create Matching rule (a match is a coverage CLAIM; null is a
good outcome), per-engine DOES / NOT FOR scope lines, stub lines marked
first-build hours, and a required `match_evidence` field enforced by
`parseAssessResponse` whenever matched_engine is set. Operational: re-assess the
three mis-matched 123 Business gaps and regenerate the plan.

**The lesson:** a catalog prompt that lists names invites nearest-neighbor
matching — selection must be framed as a coverage claim with explicit NOT-FOR
boundaries and required evidence. And any property the prompt can get wrong but
the data can decide (an engine's retrieve-worthiness) belongs in a code guard on
the data, where a wrong match degrades to a safe formulate instead of an empty
or wrong build.

## Bug #18 — matched_engine name/key contract mismatch: every catalog gap formulated (July 5 2026)

**Symptom:** a client's "Post-job Google review request" gap FORMULATED instead
of retrieving the seeded, proven `review_engine` — and 9 of 9 gaps took the slow
formulate path even though most mapped to catalog engines.

**Root cause:** the sweep's `classifyGapRoute` is a deterministic `Map.get()` of
`gaps.matched_engine` against `engine_catalog.engine_key` — but the Automation
Agent's output contract said `"matched_engine":"engine name or null"` and its
Known-engines list showed display names, so assessments persisted values like
"Review Engine (request + credit)" that can never equal a key. Three layers:
(1) the contract asked for the wrong thing; (2) matched_engine is persisted at
assessment and never re-judged, so pre-fix gaps stayed stale; (3)
parseAssessResponse accepted any string, so the bad value persisted silently and
the failure surfaced minutes later as a slow formulate — far from its cause.

**Fix (`same session`):** every Known-engines line carries `[engine_key: …]`
(three membership-ish lines all map to `membership`; the two missing engines
added; review maps to `review_engine`, never the superseded `review_request`);
the shape line demands the exact key; new `KNOWN_ENGINE_KEYS` enum shared by
prompt + `parseAssessResponse` so an unknown value fails AT WRITE TIME with a
named error. Sweep routing untouched. Operational: re-assess affected gaps —
old rows keep their stale values by design.

**The lesson:** when one AI's output is another stage's LOOKUP KEY, the contract
must name the key vocabulary exactly and the parser must enforce enum
membership at write time. A free-text field that later feeds a `Map.get()` is a
silent-formulate (or silent-anything) waiting to happen — the failure surfaces
far downstream, disguised as a performance problem.

## Bug #17 — RECURRENCE: sweep AI calls truncated at their small token limits (July 4 2026)

**Symptom:** build-plan generation with the sweep appeared hung. Console showed
`ai(): output TRUNCATED — hit max_tokens=4000` with `output_tokens: 4000` on the
sweep's per-gap AI calls.

**Root cause:** `formulateEngine` designs a full engine spec + three-tier
deployment guide in one response — well over its 4000-token cap. The truncated
JSON failed validation, and `aiJsonWithRetry` treated the truncation like a
contract violation: it re-ran the SAME call at the SAME limit, which truncated
again. Slow loop, guaranteed failure. Recurrence of Bug #17 (build-plan
generation truncation, fixed in `0c8ce60` with the 32K budget + brevity contract
+ named failure) — the sweep's new calls didn't inherit that fix, only the trap.

**Fix (same session):** `formulateEngine` → `max_tokens: 32000` (matches
`generatePlanDraft`); `adaptEngineToClient` → 8000. `aiJsonWithRetry` now
detects truncation and throws a named "output exceeded the token budget" error
immediately instead of wasting the retry on an identical call — and if a
contract-violation retry truncates, that surfaces named too.

**The new lesson:** fixtures that mock AI output CANNOT catch token-limit
truncation — a mock never hits the cap, so the dry-run passed while every live
call failed. Two rules from this:
1. Every large-output AI call sets an explicit, adequate `max_tokens` — never
   lean on a wrapper default or copy a small limit from a small call.
2. Token budgets are validated LIVE: exercise the real call once and watch
   `stop_reason`/`usage` before trusting the path. Mocked-fixture green is not
   evidence against truncation.
