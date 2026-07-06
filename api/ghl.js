// Backend proxy for all GHL Setup Agent calls.
// The browser calls /api/ghl (see the ghl() wrapper in index.html) — never
// services.leadconnectorhq.com directly (CORS-blocked, and this keeps one
// audited egress point, same rule as /api/ai).
// The per-client Private Integration Token is NOT stored here: it lives on the
// client's Supabase row (RLS) and rides in per request. Never log it.
// Whitelist matches the verified write matrix in .claude/skills/ghl-setup
// (probed live 2026-07-06). Pipelines intentionally absent until the
// Opportunities-scope probe verifies create exists in API v2.

const ACTIONS = {
  list_tags:           { method: "GET",  path: (l) => `/locations/${l}/tags` },
  create_tag:          { method: "POST", path: (l) => `/locations/${l}/tags` },
  list_fields:         { method: "GET",  path: (l) => `/locations/${l}/customFields` },
  create_field:        { method: "POST", path: (l) => `/locations/${l}/customFields` },
  list_custom_values:  { method: "GET",  path: (l) => `/locations/${l}/customValues` },
  create_custom_value: { method: "POST", path: (l) => `/locations/${l}/customValues` },
  list_calendars:      { method: "GET",  path: (l) => `/calendars/?locationId=${l}` },
  create_calendar:     { method: "POST", path: () => `/calendars/` }, // locationId forced into payload below
};

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { token, locationId, action, payload } = req.body || {};
  const spec = ACTIONS[action];
  if (!spec) {
    return res.status(400).json({ error: `Unknown action: ${String(action).slice(0, 40)}` });
  }
  if (typeof token !== "string" || !/^pit-[\w-]{20,60}$/.test(token)) {
    return res.status(400).json({ error: "token missing or not a Private Integration Token" });
  }
  if (typeof locationId !== "string" || !/^[A-Za-z0-9]{10,40}$/.test(locationId)) {
    return res.status(400).json({ error: "locationId missing or malformed" });
  }

  try {
    const isPost = spec.method === "POST";
    // locationId always comes from the request's own field — a payload can never
    // point a write at a different sub-account.
    const body = isPost
      ? JSON.stringify(action === "create_calendar" ? { ...(payload || {}), locationId } : (payload || {}))
      : undefined;

    const upstream = await fetch("https://services.leadconnectorhq.com" + spec.path(locationId), {
      method: spec.method,
      headers: {
        Authorization: `Bearer ${token}`,
        Version: "2021-07-28",
        Accept: "application/json",
        ...(isPost ? { "Content-Type": "application/json" } : {}),
      },
      body,
    });

    const data = await upstream.json().catch(() => ({}));
    return res.status(upstream.status).json(data);
  } catch (err) {
    return res.status(500).json({ error: "GHL proxy request failed", detail: String(err) });
  }
}
