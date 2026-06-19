# Output contract

Applies to every track in this review. Read it before producing any findings.

## Mode of operation
- This is a **review**: report findings only. Do **not** edit, refactor, or create files
  unless the invocation explicitly included `--fix`.
- When `--fix` is present: make the smallest correct change per finding, then summarise what
  you changed. Never bundle unrelated changes.
- Describe each fix as prose (the shape of the change). Include a code snippet only when
  `--fix` is set or the user explicitly asked for code.

## Severity
Most severe first:
- **Blocker** — must fix before merge (breaks behavior, leaks boundaries, data/regression risk).
- **Major** — should fix (clear violation that will cost the team later).
- **Minor** — worth fixing (smell, small inconsistency).
- **Nit** — optional / stylistic.

## Per-track format
Header: `### <track> — scope: <what was reviewed>`

Then findings, grouped by severity. Each finding is one short block:

    path:line — short title
      why it matters (1 line; frame around maintainability/risk, not personal taste)
      suggestion (prose; minimal diff only when --fix)

If a track finds nothing, say so in one line — do not invent findings to look thorough.
End each track with a one-line verdict, e.g. `2 blockers, 5 majors — not ready to merge`.

## Consolidated run (all tracks)
When more than one track runs, output one section per track in the order they ran, then a
final **Overall verdict**: the merge decision and the top 3 things to address first.

## Tone
Be direct and concrete. Point to the exact line. No praise padding, no restating the code back.
Prefer "rename X to Y because…" over "consider possibly improving naming".
