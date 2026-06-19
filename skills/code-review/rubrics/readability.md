# Track: readability

Lens: read the change as a whole — how much effort would another engineer spend to understand
its intent and safely extend it? This is the integrative, zoom-out pass. Do **not** re-list
micro issues already owned by `naming`, `comments`, `clean-code`, or `architecture`; a single
bad name, comment, or function is theirs. You judge how the pieces add up. Checks are
language-agnostic; examples lean toward NestJS/Vue/TS.

Check, in priority order:

1. Diff coherence — one intent or several?
   - Does the change read as one focused intent, or are unrelated edits (a fix, a refactor, a
     rename sweep, a new feature) smashed into one diff? Flag mixed intents that should be
     separate commits/PRs, and incidental churn (reformatting, reordering, moves) that buries
     the real change. Name what to split out.

2. Reading order & hidden context
   - Can a reviewer follow the change top-to-bottom without holding offscreen state in their
     head? Flag logic whose correctness depends on an unstated invariant, a side effect set
     elsewhere, call-order coupling, or magic established in another file. Name the missing
     context and where it should be made visible.

3. Control-flow legibility across the feature
   - Trace the feature's path end to end (request → service → store → component in a Nest/Vue
     app; controller → service → repository in Spring; handler → usecase → store in Go;
     view → model in Rails). Flag flow that fragments across too many hops to follow, logic
     that ping-pongs between layers/files, and a happy path obscured by branching scattered
     across the diff.

4. Consistency with neighbors
   - Does this match the patterns of the files it sits beside, or introduce a second way to do
     the same thing (error shape, DTO/return shape, store access, async style, file layout)?
     Flag one-off conventions that fragment the codebase. Point to the neighbor it diverges from.

5. Abstraction-level mixing
   - Within a unit, do statements sit at one level, or is high-level orchestration interleaved
     with low-level detail (raw SQL/`fetch` beside business steps; low-level byte/buffer
     manipulation beside domain logic; ORM/driver calls interleaved with use-case orchestration;
     DOM/formatting beside domain logic)? Flag the jarring level switches that force re-reading.

6. Discoverability — would a newcomer find it where they'd look?
   - Related things live together; each file has one concern. Would someone predict this file
     for this behavior? Flag surprising locations, logic stranded far from its siblings, and
     grab-bag files. Does the project's structure make this predictable? (a Nest module, a Spring
     package, a Go `internal/` package, a Rails `app/` folder).

7. Onboarding test
   - Would understanding this need a verbal walkthrough? If yes, name exactly what is opaque and
     the smallest structural change (split, reorder, relocate) that removes the need.

Report per the output contract.
