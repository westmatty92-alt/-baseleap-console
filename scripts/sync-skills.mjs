#!/usr/bin/env node
// Push the repo's authored SKILL.md files into the `skills` table (migration 016).
//
// DIRECTION IS THE CONTRACT: repo → DB, never DB → repo. This script has no code
// path that reads a row and writes a file. The database is a runtime copy; the
// reviewed file under .claude/skills/ is the source of truth. The table's RLS backs
// this up — it has a SELECT policy and no INSERT/UPDATE/DELETE policy at all, so the
// application cannot write a skill even if it tried. Only the service-role key can,
// and only this script holds it.
//
// Zero dependencies — hand-rolled fetch against PostgREST, so package.json stays
// empty and the repo keeps its no-node_modules character.
//
//   node scripts/sync-skills.mjs             DRY RUN (default) — reports, writes nothing
//   node scripts/sync-skills.mjs --apply     actually writes
//
// Needs, in a gitignored .env at the repo root or in the environment:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY   ← bypasses RLS entirely. Never commit it, never put
//                                 it on Vercel. Used by this script and nothing else.

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(ROOT, ".claude", "skills");
const APPLY = process.argv.includes("--apply");

const sha256 = (s) => createHash("sha256").update(s, "utf8").digest("hex");
const die = (msg) => { console.error(`\nFAIL: ${msg}\n`); process.exit(1); };

// --- env: a minimal .env reader, so there is no dotenv dependency ---------------
function loadEnv() {
  const out = { ...process.env };
  const envPath = join(ROOT, ".env");
  if (existsSync(envPath)) {
    for (const line of readFileSync(envPath, "utf8").split("\n")) {
      const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
      // Environment wins over .env, so an explicit override is never silently ignored.
      if (m && !(m[1] in process.env)) out[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  }
  return out;
}

const env = loadEnv();
const BASE = (env.SUPABASE_URL || "").replace(/\/$/, "");
const KEY = env.SUPABASE_SERVICE_ROLE_KEY || "";
if (!BASE || !KEY) die("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set (.env or environment).");

const REST = `${BASE}/rest/v1/skills`;
const HEADERS = { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" };

// --- read the repo -------------------------------------------------------------
function readSkills() {
  if (!existsSync(SKILLS_DIR)) die(`${SKILLS_DIR} does not exist.`);
  const out = [];
  for (const name of readdirSync(SKILLS_DIR).sort()) {
    const dir = join(SKILLS_DIR, name);
    if (!statSync(dir).isDirectory()) continue;
    const file = join(dir, "SKILL.md");
    if (!existsSync(file)) { console.warn(`  skip     ${name} — no SKILL.md`); continue; }
    const body = readFileSync(file, "utf8");
    if (!body.trim()) die(`${name}/SKILL.md is empty — refusing to sync a blank skill.`);
    out.push({ name, body, source_path: `.claude/skills/${name}/SKILL.md`, content_hash: sha256(body) });
  }
  return out;
}

// --- PostgREST -----------------------------------------------------------------
async function rest(url, init = {}) {
  const res = await fetch(url, { ...init, headers: { ...HEADERS, ...(init.headers || {}) } });
  const text = await res.text();
  if (!res.ok) die(`${init.method || "GET"} ${url} → ${res.status}\n${text}`);
  return text ? JSON.parse(text) : null;
}

// Upsert on the UNIQUE(name) constraint. return=representation so every write is
// verified from the row the server sends back, never assumed from a 2xx — the same
// rule CLAUDE.md sets for every Supabase write in the app.
const upsert = (rows) => rest(REST, {
  method: "POST",
  headers: { Prefer: "resolution=merge-duplicates,return=representation" },
  body: JSON.stringify(rows.map((r) => ({ ...r, synced_at: new Date().toISOString() }))),
});

// --- main ----------------------------------------------------------------------
const local = readSkills();
// A sync that finds nothing would report "0 changes" and look like success while
// silently doing nothing. Refuse instead.
if (!local.length) die("no skills found under .claude/skills/ — refusing to run against an empty read.");

const existing = await rest(`${REST}?select=name,content_hash,synced_at`);
const byName = new Map(existing.map((r) => [r.name, r]));

const toWrite = [];
const unchanged = [];
for (const s of local) {
  const row = byName.get(s.name);
  if (row && row.content_hash === s.content_hash) unchanged.push(s.name);
  else toWrite.push(s);
}

// A DB row with no matching directory. REPORTED, NEVER DELETED: a missing directory
// may be a rename in progress, and silently dropping the row the Audit prompt loads
// would break the prompt at the worst possible moment. Deletion stays a deliberate,
// separate act.
const orphans = existing.filter((r) => !local.some((s) => s.name === r.name)).map((r) => r.name);

const list = (a) => (a.length ? "  " + a.join(", ") : "");
console.log(`\n  mode       ${APPLY ? "APPLY — writing" : "DRY RUN — no writes (pass --apply to write)"}`);
console.log(`  repo       ${local.length} skill(s)`);
console.log(`  unchanged  ${unchanged.length}${list(unchanged)}`);
console.log(`  to write   ${toWrite.length}${list(toWrite.map((s) => `${s.name} (${byName.has(s.name) ? "update" : "insert"})`))}`);
console.log(`  orphaned   ${orphans.length}${orphans.length ? list(orphans) + "   ← in DB, not in repo. NOT deleted." : ""}`);

if (!toWrite.length) { console.log("\n  nothing to do.\n"); process.exit(0); }
if (!APPLY) { console.log("\n  dry run — no writes made.\n"); process.exit(0); }

const written = await upsert(toWrite);
console.log(`\n  wrote ${written.length} row(s):`);

// Verify from what the server returned, not from what was sent. Re-hashing the
// returned body proves the stored text is byte-identical to the file that produced
// it — which is exactly the check the loader will later make at read time.
let bad = 0;
for (const s of toWrite) {
  const w = written.find((r) => r.name === s.name);
  const ok = !!w && w.content_hash === s.content_hash && sha256(w.body) === s.content_hash;
  if (!ok) bad++;
  console.log(`    ${ok ? "ok  " : "BAD "} ${s.name}  ${s.content_hash.slice(0, 12)}`);
}
if (bad) die(`${bad} row(s) came back not matching the file that produced them.`);
console.log("\n  all rows verified against their source files.\n");
