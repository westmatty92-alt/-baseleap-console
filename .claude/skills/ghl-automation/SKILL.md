# ghl-automation

## What it is
The Automation Agent's GHL capabilities reference: what a GHL workflow can natively
trigger on and do, where native stops and n8n begins, and the operating rules for
feasibility calls and build plans. Distilled from the Master Workflow Triggers/Actions
manuals, the CRM Workflow Actions manual, the Getting Started with Workflows standard,
and the Payments cross-section agent rules (all verified against official HighLevel
docs July 1–2, 2026). The LIVE workflow builder is always the final authority — GHL
ships changes by account/plan/Labs; this file is for feasibility and scoping, and every
build step must still be verified in-UI.

## When to use it
Read before any Automation Agent work: assessing a gap (feasible/mechanism/hours),
tagging approach, or (Phase C) drafting build-plan steps. Pairs with automation-catalog:
this file answers "can GHL do it natively, and via what trigger/action"; the catalog
answers "have we templated it and what does it cost."

## Trigger vocabulary (what a workflow can fire on)
**Contact:** Contact Created · Contact Changed · Contact Tag (added) · Contact DND ·
Birthday Reminder · Custom Date Reminder · Note Added/Changed · Task Added/Reminder/
Completed · Trigger Link Clicked · Contact Engagement Score
**Opportunity:** Opportunity Created · Opportunity Changed · Pipeline Stage Changed ·
Opportunity Status Changed (Open/Won/Lost/Abandoned) · Stale Opportunities ·
Order Form Submission · Order Placed · Order Fulfilled
**Company (B2B):** Company Created · Company Changed
**Comms/events:** Form Submitted · Survey Submitted · Customer Replied · Inbound Email ·
Email Events (delivered/opened/clicked/bounced/unsubscribed) · Call Status ·
Messaging Error Code (SMS) · Transcript Generated · Live Chat triggers ·
Exact Match/Contains Phrase (keyword reply)
**Appointments:** Appointment Status (created/rescheduled/canceled/confirmed/showed/
no-showed — filter by exact calendar + status) · Customer Booked Appointment
(self-booked ONLY; staff-created bookings need Appointment Status)
**Payments:** Payment Received (money truth — funnel/invoice/calendar/form/membership/
manual sources) · Invoice (Paid/Partially Paid/Sent/Viewed/Void) · Subscription
(trial/active/canceled — lifecycle state, NOT payment) · Refund · Order Submitted ·
Estimates · Product Access Granted/Removed · Coupon Applied/Redeemed/Limit/Expired
**Documents & Contracts:** signed / declined / viewed (the post-agreement boundary
trigger — contract signed → onboarding/build-plan kickoff)
**Ads/social:** Facebook Lead Form Submitted · FB/IG Comments on Post · TikTok Form
Submit · LinkedIn Lead Form Submitted
**Courses/communities (non-beachhead):** Category/Product Completed · Offer Access
Granted/Removed · Courses New Sign Up · Group Access Granted/Revoked · Private Channel
**Other:** Funnel/Website Page View · Abandoned Checkout (e-comm) · Shopify Abandoned
Cart · Product Review Submitted (e-comm) · Start IVR · Scheduler (time-based) ·
Inbound Webhook (premium — the n8n→GHL entry point)

## Action vocabulary (what a workflow can do)
**Send:** Send Email · Send SMS · WhatsApp (+ service-window check) · Voicemail (drop) ·
Call / Manual Call / Manual SMS (human-execution queue) · Internal Notification
(email/in-app/SMS to user/role/team/owner — the "alert the team" layer) · Slack ·
GMB message · Review Request (the Review Engine primitive) · FB/IG Messenger ·
Instagram DM · Reply in Comments · Drip (throttled batch sending)
**Contact/CRM:** Create Contact · Find Contact (→ found/not-found branches) · Update
Contact Field · Add/Remove Contact Tag (append-only, non-destructive) · Add to Notes ·
DND Contact · Assign to User / Remove Assigned User · Add/Remove Follower · Modify
Engagement Score · Log External Call · Generate One-Time Booking Link · Merge Contact ·
Copy to Sub-Account · Delete Contact (destructive — approval-gated, backup first)
**Opportunity:** Create Opportunity (intentional duplicates) · Find Opportunity →
Update Opportunity (one exact deal) · Create/Update Opportunity (upsert) · Remove
Opportunity · Add/Remove Owner · Add/Remove Followers
**Company & custom objects:** Create and Associate Company · Update Associated Company ·
Clear Associated Company Fields · Create/Update/Clear Associated Record ·
Find Object Record / Find Company (webhook data → record) · Add/Remove Associated
Records to/from Workflow (cross-object fan-out)
**Data/state:** Update Custom Values (account-level state WRITE — referral tokens etc.) ·
Math Operation · Text / Number / Date-Time / Array Formatter · Custom Code ·
Google Sheets (premium)
**Flow control:** Wait (duration/date/event/reply/condition — ALWAYS set a timeout) ·
If/Else (deterministic branching; always keep a None/Else fallback branch) · Split
(percentage A/B) · Go To · Goal Event (jump-on-outcome) · Add to Workflow / Remove from
Workflow (orchestration — document dependencies, prevent circular enrollment) ·
Set Event Start Date
**Payments:** Stripe One-Time Charge · Send Invoice · Send Recurring Invoice ·
Send Estimate · Send Documents & Contracts (workflow sends the contract; templates
populate from opportunity/custom values)
**Appointments:** Update Appointment Status (can cascade into other appointment
workflows — map the loop)
**AI steps (metered):** GPT / AI Agent / Decision Maker / Intent Detection / Summarize /
Translate / Extract Data · Conversation AI actions · Invoke Agent Studio Agent
**Integrations:** Webhook (outbound POST) · Custom Webhook (OAuth2 or managed masked
credentials — never paste secrets into steps/notes) · Google Analytics / Google Ads ·
IVR Say/Play / Gather Input / Connect / End · Affiliate Manager actions ·
Course Grant/Revoke Offer

## Semantics that change feasibility calls
- **Payment truth:** only Payment Received (with transaction ID) proves money. Form
  submitted, order-form submission, product/offer access granted, invoice Sent/Viewed,
  subscription "active" — none are payment. Engines that award value (session credits,
  referral rewards, fulfillment) must gate on Payment Received + idempotency token.
- **Subscription ≠ payment:** Subscription trigger = lifecycle state; renewals confirm
  via Payment Received. Dunning logic reads failed/past-due states distinctly.
- **Appointment lifecycle** is fully native (booked→confirmed→showed/no-show→canceled/
  rescheduled) — the Booking Lifecycle engine needs no external parts.
- **Email opens are unreliable** (scanners/privacy inflate them). Route on clicks,
  replies, or business outcomes — never high-stakes decisions on opens.
- **Re-entry & duplicates:** design every trigger for repeat events (multiple clicks,
  duplicate provider webhooks, workflow-generated events). Use tags/fields as
  processed-state markers; find-before-create on records.
- **Record context:** an action only sees records in its workflow context — contact
  actions need a contact; cross-object values don't resolve automatically (Company
  merge fields are blank unless the contact is associated to a Company).
- **DND/consent/A2P:** sends respect DND + STOP. SMS engines DELIVER only after A2P
  registration; email engines only after domain auth (SPF/DKIM/DMARC) — both are Setup
  Agent prerequisites. Flag as build-plan dependencies, not automation steps.

## Native-vs-external boundary map
Rule of thumb: **automation living in GHL's own data (contacts, opps, appointments,
reviews, GHL-processed payments) → native build. Reading/writing an external
system-of-record's data → n8n bridge.**
- **Stripe → NATIVE.** Connect, one-time charge, refund-status sync. (Why the Payment
  Foundation engine is Stripe-first.) Other processors = net-new/external.
- **Facebook/IG leads → NATIVE.** Lead Ads sync, form mapping, lead→workflow,
  Conversions API.
- **Google Business Profile → NATIVE** for review collection/management (Review Engine).
- **Jobber → NATIVE two-way contact sync** (the sync itself; deeper job-data automation
  is external).
- **QuickBooks → EXTERNAL (n8n + QB API).** GHL's entire native QB integration is one
  automation: review-request after first invoice paid. Invoicing sync, deposit
  requests, progress payments, dunning on QB = n8n bridge — price as heavy integrate.
- **Invoicing fork (apply per client):** no invoicing tool → GHL-native invoicing
  (build; full native lifecycle: send/reminders/paid-triggers). Entrenched external
  invoicing (e.g. QuickBooks) → n8n bridge (integrate, heavier hours).
- **n8n↔GHL plumbing:** inbound = Inbound Webhook trigger (premium); outbound =
  Webhook/Custom Webhook actions. HMAC verify; ~100 req/10s rate limit.

## Cost inputs for estimates
- **Premium executions** (Inbound Webhook, Google Sheets, Slack, Custom Webhook,
  Workflow AI, marketplace apps) are metered: free 100 lifetime, then tiers —
  $10/mo:10k · $25/mo:30k · $50/mo:65k, overage $0.004–0.01/exec. Agency can enable +
  rebill at markup (SaaS Configurator). High-volume webhook-bridged engines = model
  execution cost (enrollments × premium steps reached) before pricing; verify live
  pricing page at proposal time.
- AI steps, SMS/email/voice usage are metered separately (rebilling margin layer).

## Operating rules (the test gate, confirmed by GHL's own docs)
1. Identify the business event first; pick the trigger whose semantics match exactly —
   never by similar wording. Prefer Current articles over legacy/deprecating.
2. A saved step is not a working step. Never publish because it saved — resolve builder
   errors, run Test Action on integrations (tests are LIVE — use controlled records),
   inspect Execution Logs + enrollment history, validate downstream side effects.
3. Test matrix per workflow: happy path · not-eligible · every branch · missing data ·
   duplicate/re-entry · external-app failure · timezone boundary · stop/rollback.
4. Approval-gated (never auto-execute): publishing, real-audience sends, refunds/
   charges/billing changes, deletions, credential rotation, app installs.
5. Payments extra: separate Test/Live modes; treat pending ACH as unpaid; dedupe on
   transaction/order/invoice IDs; never store raw card data or secrets in CRM records;
   reconcile against the provider — workflow success ≠ settlement.
6. Record in the build plan: trigger config, expected payload, fallback path, owner,
   verified date.
