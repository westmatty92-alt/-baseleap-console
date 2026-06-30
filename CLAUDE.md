# CLAUDE.md — Baseleap Console

## What this is
The internal agency console for Baseleap's client-acquisition suite. One single-file app
(`index.html`) with a sidebar and a business-switcher dropdown. Five modules live inside it:
Client Research, AI Audit Assistant, Automation Agent, Gap Report Builder, Proposal Generator.

It is INTERNAL — Matthew uses it to win and onboard clients. It is NOT resold or embedded in
client sub-accounts (that's Pulse). It embeds once at the GHL agency level.

## Session start
1. Read this file, `REFERENCES.md`, and `MASTER_BUILD_GUIDE.md`.
2. Read the Notion track plan and the highest-priority incomplete item.
3. State what you're about to build and which files you'll touch. Wait for confirmation.

## Non-negotiable rules
- Single `index.html`. Modules are sections inside it, not separate files.
- All AI calls go through `ai()` → `/api/ai`. Never raw fetch to Anthropic.
- Every Supabase insert stamps `operator_id: S.user.id` (RLS).
- New per-client state goes in `resetClientState()` so the client switch stays clean.
- Modal/overlay backgrounds use hardcoded hex, never CSS variables.
- Keep functions short. No monolithic mega-functions (the openAdView SyntaxError trap).
- Brand tokens only (see `:root` in index.html): Midnight #0D1F2D, Volt #00D4A0, Run #00A878,
  Canvas #F4F5F0, Depth #1A1A2E.

## Build order (modules)
1. Audit Assistant (first — defines how gaps get written)  ← current
2. Automation Agent (feasibility gate)
3. Gap Report Builder
4. (packages/pricing decided)
5. Proposal Generator
6. Client Research + Automation Agent RAG hardening

## Schema
`baseleap_console_schema_v1.sql` — run once in the Supabase SQL editor. Seven tables, RLS on all.
