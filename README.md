# Baseleap Console

Internal agency console for Baseleap's client-acquisition suite. One single-file app with a
business-switcher dropdown and five modules: Client Research, Audit Assistant, Automation Agent,
Gap Report Builder, Proposal Generator. Internal tool — not resold (that's Pulse).

## Stack
- `index.html` — the whole front end (single file)
- `api/ai.js` — Vercel serverless proxy for Claude (holds the Anthropic key)
- Supabase — auth + Postgres (RLS) + Storage
- Vercel — hosting

## Setup
1. Run `baseleap_console_schema_v1.sql` in the Supabase SQL editor (creates 7 tables, RLS on).
2. Create a user in Supabase Auth (the operator login).
3. Set `ANTHROPIC_API_KEY` in Vercel → Settings → Environment Variables.
4. Deploy to Vercel.

## Docs
- `CLAUDE.md` — agent session start + rules
- `REFERENCES.md` — ai() wrapper, Supabase patterns, RLS
- `MASTER_BUILD_GUIDE.md` — architecture + known-bug checklist
