// Backend proxy for all Claude calls.
// The browser calls /api/ai (see the ai() wrapper in index.html).
// The Anthropic key lives ONLY here, in the ANTHROPIC_API_KEY env var on Vercel.
// This is what keeps a raw browser->Anthropic fetch (and the CORS/key-leak bug) from ever happening.

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    return res.status(500).json({ error: "ANTHROPIC_API_KEY is not set on the server" });
  }

  try {
    const { system, messages, model = "claude-sonnet-4-6", max_tokens = 1500 } = req.body || {};

    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({ model, max_tokens, system, messages }),
    });

    const data = await upstream.json();
    return res.status(upstream.status).json(data);
  } catch (err) {
    return res.status(500).json({ error: "Proxy request failed", detail: String(err) });
  }
}
