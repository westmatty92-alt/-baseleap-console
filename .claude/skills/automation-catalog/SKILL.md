# automation-catalog

## What it is
The Agent's in-context reference for the automations Baseleap builds. Mirrors the human-facing
"⚙️ Automation Engine Catalog" Notion database. Use it to match a gap to a known engine, pick
approach, and estimate cost-to-deliver using the two-number snapshot model. Keep conceptually
in sync with the Notion DB (Notion is master; this is what the Agent reads).

## The two-number snapshot model (critical)
GHL automations snapshot: once built, they're cloned into a new client's sub-account and only
client-specific bits are wired up. Cost-to-deliver has two numbers:
- first-build hrs = build from scratch (one-time, higher)
- deploy hrs = snapshot + parameterize for a new client (repeats, much lower)
For a TEMPLATED engine → estimate DEPLOY hours, UNLESS approach is integrate/replace with
genuine per-client wiring (then use the higher end). For a NEW/untemplated gap → estimate
FIRST-BUILD hours and set is_new_template:true (first client pays for a reusable asset).
estimated_hours = internal cost-to-deliver only. BAND sets the client price regardless of hours.

## Approach rule (read current_stack first)
- build = nothing exists → net-new (GHL, or n8n if GHL can't do it)
- integrate = client already runs a capable tool → connect it, don't replace
- replace = client runs fragmented/manual tools doing the job badly → consolidate into GHL

## Snapshot-ability by approach
- build (GHL-native) → highly templatable, low deploy cost
- integrate (webhook/API to client's own tool) → partially; their-system wiring is real per-client work
- replace → GHL side templates; data migration/cutover does not

## Known engines
| Engine | Category | Approach | Templated | Deploy hrs | Band | Notes |
|---|---|---|---|---|---|---|
| Meta Lead Follow-Up Drip | lead capture | build | yes | <1 day | Standard | timeline-branched drip; snapshot ready |
| Booking Lifecycle (confirm/cancel/complete) | booking | build | yes | <1 day | Standard | universal; swap services + branded emails |
| Payment Processor Foundation (Stripe) | foundation | integrate | yes (Stripe) | <1 day | Standard | FOUNDATIONAL — build first; Stripe is the built path, other processors = net-new |
| Referral & Loyalty | referral | build | yes | 1–3 days | Complex | webhook A→B + tier; swap credit/tiers/points |
| Review Engine (request + credit) | reviews | build | yes | <1 day | Simple | post-service request; optional review-credit reward |
| Session Decrement | membership | build | yes | <1 day (DFY) | Standard | payment-truth guard + floor; pairs w/ Booking-Lock |
| Membership Booking-Lock | membership | build | yes | <1 day | Standard | Sessions-Remaining gatekeeper tag |
| Reactivation Gate (membership) | retention | build | yes | <1 day | Standard | state cleanup on re-pay; NOT a marketing win-back |

## Dependency order
Payment Foundation first → then payment-triggered engines (booking Won-state, session decrement,
referral revenue awards) → loyalty/membership on top. Flag if a gap needs a prerequisite not yet in place.

## Not-yet-templated (net-new first-builds when a client needs them)
- Marketing win-back drip for lapsed customers (common gap; model on the Meta timeline pattern) → Standard, first-build.
- Any gap with matched_engine=null → is_new_template:true, estimate first-build.

## Curated-learning loop
When a gap has no matching engine, set is_new_template:true — a signal for the OPERATOR to add it
to the catalog AFTER building (real mechanism, real first-build + deploy hrs). The Agent proposes;
the operator confirms what graduates. Never auto-write — the catalog is also the price sheet.

## Bands (client price anchor, from real SOP pricing)
Simple $500–1,000 · Standard $1,500–3,000 · Complex $3,500–6,000+. Referral full program $2,500–6,000.
