## What it is
Probing heuristics for a discovery call — the questions that turn "we do X"
into a buildable picture of HOW X actually runs, for the Baseleap Console
Audit Assistant.

## When to use it
Read alongside audit-discovery before any work on analyzeGaps(). This one
governs what the transcript SHOULD contain; audit-discovery governs what to do
with what it does contain.

## The three probes that change a build
- **Frequency and volume, never just existence.** "We send reminders" is not a
  fact you can build on. Per day? Per week? By whom? A twice-a-year task is not
  worth automating; a forty-times-a-day one is the whole engagement.
- **What happens when the usual person is out.** The answer names the single
  points of failure, the undocumented steps, and the work that silently stops.
  A process only one person can run is a gap even when it currently works.
- **How handoffs between steps are tracked.** Between two people, or two tools,
  is where things are dropped. "They just know" and "it's in her inbox" are both
  findings, not answers.

## Reading a transcript that lacks these
The notes usually record WHAT happens and omit how often, who covers, and what
carries state between steps. When a gap's frequency, owner or handoff is absent,
say so in the gap's own words rather than inventing a number — an unquantified
gap is still a gap, and a fabricated volume corrupts the estimate that follows.

## What happens if you skip it
Gaps come out as restatements of the client's own summary — true, unbuildable,
and impossible to price. "Manual invoicing" is a topic. "Two hours every Friday,
one person, tracked in her head" is a specification.
