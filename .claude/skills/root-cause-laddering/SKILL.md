## What it is
A technique for moving from the symptom a client reports to the root cause an
automation can actually fix, for the Baseleap Console Audit Assistant.

## When to use it
Read alongside audit-discovery before any work on analyzeGaps(). Apply it to
every gap before writing its problem field.

## The ladder
Ask why the stated problem happens, then why THAT happens, until you reach a
cause that maps to something buildable. Usually two or three rungs.

  "We lose leads"                        ← symptom, unbuildable
  → why? nobody follows up same day      ← still a behaviour
  → why? nothing tells them a lead came  ← THIS is the rung that maps

## Stop at the buildable rung — not the deepest one
Laddering past the automatable cause reaches true but useless answers
("because we're understaffed", "because the owner is busy"). The correct stop is
the last rung an automation can act on. One more why is not better analysis; it
is a gap nobody can build.

## Keep the symptom, it is what they will recognise
The root cause goes in the gap's problem field; the client's own words for the
symptom go in cost or alongside it. A gap phrased purely as a root cause reads
as something the client never said and will be argued with in the debrief.

## What happens if you skip it
Gaps mirror the complaint back. "Leads fall through the cracks" cannot be
scoped, estimated, or matched to an engine — three separate downstream steps
fail on the same missing rung.
