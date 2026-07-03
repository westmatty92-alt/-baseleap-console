# ghl-setup

## What it is
The Setup Agent's reference for standing up a client GHL sub-account: provisioning,
the dependency-ordered foundational sequence, and the two messaging-delivery gates
(A2P for SMS, domain auth for email). Distilled from the Foundational Setup manual,
the Phone System A2P/10DLC section, the Email deliverability reference, and the SaaS
Configurator provisioning articles (all verified against official HighLevel docs
July 1–2, 2026). The live UI and Trust Center are always the final authority.

## When to use it
Read before any Setup Agent work: provisioning a new sub-account, auditing an
existing one, or generating setup steps for a build plan. Pairs with ghl-automation:
setup builds the substrate (fields, domains, numbers, calendars, pipelines) that
automations run on. **Setup before Automation — a workflow must never be published
before the assets it references exist.**

## Provisioning (operator-level, before the foundation)
- The SaaS plan is the permission ceiling: it defines which features the sub-account
  gets; user permissions can only subset it. Test with an agency user AND a client user.
- Create via SaaS checkout (auto-generates the sub-account) or convert an existing
  location (Switch to SaaS → link payment method → plan holds until card added).
  Label everything SaaS V1 vs V2 — different providers, wallets, taxes, lifecycle.
- Guards to configure: **manual approval** of new accounts (review identity/risk
  before release; define an SLA), **2FA** before phone-number purchase (never bypass
  to speed onboarding), **user limits** (applies to sub-account users, not agency
  users), **contact limits** (UI-only — API/forms/workflows bypass it; not a hard cap).
- Customize the onboarding/welcome email (no passwords or credentials in it; verify
  white-label domain + support details) and the account naming convention.
- "Sub-accounts not generating" (V1): agency and selling sub-account must use the
  same Stripe account, live keys not test keys.

## The foundational sequence (dependency-ordered — do not reorder)
**Step 0 — context gate.** Before changing anything, verify: correct agency/
sub-account, user permissions, business timezone, sending domain, phone number,
owner. Record what already exists; inspect and test existing assets before
accepting them as complete.
1. **Business profile & data model** — custom fields (controlled types wherever
   automations will branch/filter on the value), tags, sources, naming conventions,
   an internal test contact. Import contacts as a controlled migration: clean CSV
   (≤50MB), map fields (never merge different concepts into one field), preserve
   consent + DND — never invent consent during import.
2. **Domains & DNS** — connect and verify the web domain (gates funnel/form launch)
   and choose the dedicated email sending subdomain (gates step 4). DNS propagation
   takes time; compare current records against GHL's instructions before replacing.
3. **Phone & A2P** — purchase the number, configure forwarding + test call, then
   START A2P REGISTRATION IMMEDIATELY (approval has lead time; see gate below).
4. **Email deliverability** — dedicated subdomain, SPF/DKIM/DMARC, headers,
   warm-up (see gate below).
5. **Lead capture** — funnel + form. Required custom fields must exist BEFORE the
   form is finalized; forms collect only data with an operational/consent purpose.
   Test submission creates/updates the expected contact exactly once.
6. **Outbound & follow-up** — email template → test on desktop+mobile → campaign
   (final audience/exclusions/sender/unsubscribe recheck before send). Follow-up
   workflows: trigger filtered to the exact form/event, re-entry defined, waits
   respect business hours, DND preserved, goal/exit logic set, PUBLISHED not drafted.
7. **Scheduling** — the host must exist as a user first (even a solo operator).
   Calendar type + availability + booking rules; connect personal calendar + video;
   confirmation/reminder workflow; test a full visitor booking including cancel/
   reschedule.
8. **Pipelines & opportunities** — stages must mirror the real operational handoffs
   (adapt, don't copy examples). Opportunity creation is intentional: define the
   duplicate policy (one opp per contact/service/transaction/cycle) BEFORE enabling
   Create/Update Opportunity moves in workflows.

**Hard dependency rules:** custom fields → forms → workflows. Domain verified →
funnel live AND email subdomain possible. A2P approved → any SMS engine live.
Email auth + warm-up → any campaign send. Host user → calendar. Pipeline + duplicate
policy → opportunity workflows. Payment provider connected → SaaS/rebilling active.

## A2P/10DLC — the SMS-delivery gate (US local numbers)
Without registration, SMS gets filtered/blocked — every client receiving SMS
automations needs this BEFORE any SMS engine goes live. It is the phone twin of
email domain-auth.
- **Sequence:** register the BRAND (legal name + EIN exactly matching official
  records, address, website, business-domain email, authorized contact, possible
  email OTP) → then the CAMPAIGN (use case matching the real traffic; sample
  messages that identify the brand and include HELP/STOP; public opt-in evidence)
  → then assign approved numbers. Wait for approval before production sending.
- **Opt-in evidence:** a published page/form with an UNCHECKED consent checkbox and
  clear frequency/fees/HELP/STOP disclosures; publicly accessible privacy policy +
  terms consistent with the form; never pre-check consent or bundle it with
  unrelated terms.
- **Sole-proprietor path** exists for eligible one-person no-EIN businesses only
  (limited numbers/campaigns) — never use it for an incorporated/EIN business.
- Run the AI pre-submission validation; the **Trust Center is the operational source
  of truth** for status. Rejections list required fixes — correct every item; some
  rejection types need a NEW campaign, not an edit; never resubmit unchanged.
- **Costs & throughput:** brand + campaign vetting fees, recurring campaign fees,
  per-SEGMENT carrier fees (+ platform markup) — include in client pricing; verify
  live values. Throughput (MPS) is per-campaign, measured in segments, shared across
  its numbers — pace workflow sends below the approved capacity.
- Canada has its own 10DLC rules; US approval does not transfer to other countries.
  Check the forbidden-categories list before registering any campaign.

## Email deliverability — the email-delivery gate
- **Dedicated sending subdomain** (e.g. `lc.clientdomain.com`) via Settings → Email
  Services → Dedicated Domain and IP; then Set Headers (From Name / From Email that
  recipients recognize; a From that doesn't align with the authenticated domain
  shows "via" and hurts placement).
- **The auth trinity:** ONE valid SPF record (multiple SPF records break auth),
  DKIM selector/key copied exactly, DMARC at `_dmarc` starting with a monitoring
  policy — tighten only after alignment is proven.
- **DNS gotchas:** duplicate SPF, MX conflicts, wildcard conflicts, and Cloudflare
  proxying on mail/tracking records are the classic breakers. Propagation can take
  24–48h; verify in GHL, then confirm SPF/DKIM/DMARC all = pass in a real test
  message's headers.
- **Warm-up is enforced:** LC Email applies staged daily limits with graduation;
  send to recent, engaged, permission-based contacts; keep volume stable (no
  spikes); bounce/complaint spikes pause graduation or suspend sending. A new
  sub-account cannot bulk-send on day one — schedule campaigns accordingly.
- Verification ≠ permission: email-address verification reduces bounces but is not
  marketing consent. Monitor Gmail Postmaster / Microsoft SNDS as volume ramps.

## Operating rules (the setup test-gate)
1. Confirm context first (step 0) — never change an account you haven't verified.
2. Protect data: contact deletion cascades (conversations, opportunities, tasks,
   appointments) and stops active workflows — restorable ~2 months; never delete as
   routine cleanup; prefer tags/archive logic. Never overwrite imports or change
   dedup behavior without documented authorization.
3. Respect consent: a phone number or email on file is NOT permission to market.
   Preserve DND/unsubscribe/import-consent through every step.
4. Test with controlled records (the internal test contact) before bulk anything.
   Bulk sends are irreversible once sent; recheck filters, DND exclusions, sender,
   and timezone at the gate.
5. A saved draft is not active. Confirm final PUBLISHED/verified status of funnels,
   campaigns, workflows, calendars, and domains before declaring completion.
6. Stable naming: `WF - [Trigger] - [Outcome] - [Version]`, `FORM - [Purpose] -
   [Source]`, `CAL - [Service] - [Host]`, `PIPE - [Process]`, tags
   `[Prefix]-[Category]-[State]` — never "Workflow 1".
7. Record evidence in the implementation log: asset name + path, purpose/owner,
   trigger/filters, key config, dependencies, test contact + date, expected vs
   actual result, approval status, known limitations.
8. **Completion rule: a feature is complete only when a controlled test produced
   the expected result, the result is documented, and unresolved risks are
   disclosed.** Configured ≠ complete. (LaunchPad nudges are support hints, never
   proof a step is done.)
