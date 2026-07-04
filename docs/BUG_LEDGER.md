# BUG LEDGER — Baseleap Console

Numbered incidents and the lesson each one bought. Numbering continues the bug
history in the Notion Console spec; entries land here when the lesson should sit
next to the code. Newest first.

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
