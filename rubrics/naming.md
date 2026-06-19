# Track: naming

Lens: does every name reveal intent and match what the thing actually does?
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Intention-revealing
   - A name should answer why it exists and how it's used. Flag single letters (except trivial
     loop indices), and abbreviations that aren't domain-standard.

2. Honesty
   - The name must match the behavior. Flag misleading names (a `get*` that mutates, an
     `isValid` that throws) and stale names left over after a change.

3. Domain language
   - Use the project's ubiquitous language. Flag noise words — `data`, `info`, `manager`,
     `helper`, `util`, `processData` — that carry no meaning. Name the actual concept.

4. Grammar
   - Functions/methods are verbs or verb phrases; classes/types/components are nouns.
   - Booleans read as predicates: `is…`, `has…`, `should…`, `can…`.

5. Conventions & casing
   - camelCase for variables/functions, PascalCase for classes/types/Vue components,
     UPPER_SNAKE for constants, the project's file-naming convention for files.
   - NestJS: consistent provider suffixes (`*Service`, `*Repository`, `*Controller`).
   - Vue: composables named `useX`; components are multi-word PascalCase.

6. Consistency across the codebase
   - The same concept has the same name everywhere. Flag two names for one idea (and one name
     for two ideas). Avoid abbreviations that hurt code search.

Report per the output contract. When a comment exists only to explain a bad name, the fix is a
rename, not a comment — note that.
