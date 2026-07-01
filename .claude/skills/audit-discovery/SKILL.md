## What it is
Domain knowledge for turning a discovery-call transcript into a set of
business gaps for a Canadian SMB, for the Baseleap Console Audit Assistant.

## When to use it
Read before any work on the Audit Assistant's analyzeGaps() / gap-analysis logic.

## Core rule — atomic itemization
- Identify every distinct, separately-solvable workflow gap as its own item
- Map each gap ~1:1 to one automation that could be built and priced independently
- Scale gap count to transcript richness (a rich transcript = 6-9 atomic gaps); never cap at three
- Keep lead-capture separate from lead-response, reminders separate from calendar, reviews separate from retention
- Always surface manual invoicing / payment-chasing as its own gap
- Slight over-splitting is correct — the Automation Agent (feasibility gate) consolidates buildable overlaps downstream

## Severity
high = costs real money/jobs now or names a confirmed loss; medium = wastes
meaningful time or revenue but no confirmed loss; low = minor friction.

## Categories
gap | tool | pain | win

## Output contract
JSON {summary, gaps:[{title, problem, cost, severity, category}]} → written to
the Supabase gaps table with validation_status='pending'. Use the client's own
words in problem and cost.

## What happens if you skip it
Gaps collapse into ~3 broad themes, the proposal under-scopes, and the client's
stated top pain can vanish (invoicing was dropped on the first live test until
itemization was enforced).
