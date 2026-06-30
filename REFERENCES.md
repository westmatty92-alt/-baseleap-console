# REFERENCES — Baseleap Console

Patterns the agent reuses in every session. Read this before writing module code.

## AI calls — always via the proxy, never raw to Anthropic

Browser side (already defined in `index.html`):

```js
const text = await ai({
  system: "You are ...",
  messages: [{ role: "user", content: "..." }],
  max_tokens: 1500,            // model defaults to claude-sonnet-4-6
});
```

`ai()` POSTs to `/api/ai`. The Anthropic key lives only in the serverless function
(`api/ai.js`) via the `ANTHROPIC_API_KEY` env var. A raw `fetch('https://api.anthropic.com...')`
from the browser is the #1 forbidden bug — CORS failure and a leaked key. Never do it.

## Supabase

Client is initialised in `index.html`:

```js
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

- Project URL: `https://qqgdzwkbuzciocnyimje.supabase.co`  (bare URL — no `/rest/v1/`)
- anon key: public, lives in the browser, safe because RLS enforces `operator_id = auth.uid()`.
- service_role key: NEVER used in this app. It bypasses RLS.

### RLS rule for every insert
Every insert MUST stamp `operator_id: S.user.id`, or the `WITH CHECK` policy rejects it
("violates row-level security policy"). Example in `createClient()`.

## The client record is the data contract

All modules read/write rows keyed to `S.activeClientId`. Tables: `clients`, `audit_sessions`,
`gaps`, `build_plans`, `gap_reports`, `proposals`, `client_files`. The `gaps` table carries the
feasibility-gate fields (`feasible`, `mechanism`, `estimated_hours`, `validation_status`).
The Gap Report module only reads gaps where `validation_status = 'validated'`.

## Load-client state reset (the switchBusiness discipline)

`loadClient(id)` calls `resetClientState()` BEFORE loading new data. Any new per-client state a
module introduces must be cleared there too, or client B will see client A's data.

## Env vars (Vercel → Settings → Environment Variables)

- `ANTHROPIC_API_KEY` — server-side only. See `.env.example`.
