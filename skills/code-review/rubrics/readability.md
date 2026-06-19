# Track: readability

Lens: how much effort would another engineer spend to understand and safely change this?
This is the integrative, zoom-out pass. Do **not** re-list micro issues already owned by
`naming`, `comments`, or `clean-code` — focus on coherence, consistency, and onboarding cost.
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Cognitive load
   - Can a reader follow the flow top-to-bottom without jumping across many files to hold the
     logic in their head? Flag logic that only makes sense with hidden context.

2. Consistency with the codebase
   - Does this follow the patterns already used here, or introduce a new style for the same
     problem? Flag one-off conventions that fragment the codebase.

3. Organization & discoverability
   - Related things live together; files have one clear concern and a reasonable length. Could
     someone predict where a given behavior is implemented? Flag surprising locations.

4. Coherent narrative
   - Names, structure, and the few necessary comments should tell one consistent story. Flag
     places where they pull in different directions.

5. Public-surface ergonomics
   - Consistent return shapes and predictable error surfaces for callers. Vue: clear component
     responsibility, documented props/emits. NestJS: discoverable module structure.

6. Onboarding test
   - Would this need a verbal walkthrough to be understood? If yes, name what specifically is
     opaque and the smallest change that would remove the need.

Report per the output contract.
