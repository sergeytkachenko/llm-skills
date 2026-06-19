# Track: naming

Lens: does every name reveal intent and match what the thing actually does?
Checks are language-agnostic; examples lean toward NestJS/Vue/TypeScript.

Check, in priority order:

1. Honesty
   - The name must match the behavior. Flag misleading names (a `get*` that mutates, an
     `isValid` that throws, a `fetchUser` returning cached data) and stale names left after a
     change. Names for deferred work read as the action (`loadUser`, `saveOrder`), never as the
     resolved value — applies to any async/Promise/Future/coroutine return.

2. Intention-revealing
   - A name answers why it exists and how it's used. Flag single letters (except trivial loop
     indices), and abbreviations that aren't domain-standard. Encode units when ambiguous:
     prefer `timeoutMs`, `sizeBytes`, `maxRetries` over `timeout`, `size`.

3. Domain language
   - Use the project's ubiquitous language. Flag noise words — `data`, `info`, `manager`,
     `helper`, `util`, `processData` — that carry no meaning. Name the actual concept.

4. Grammar & predicates
   - Functions/methods are verbs or verb phrases; classes/types/components are nouns.
   - Booleans read as positive predicates: `is…`, `has…`, `should…`, `can…`. Flag negatives
     that double-negate — prefer `enabled` over `disabled`, `isVisible` over `isHidden`.
   - Collections are plural and match their element (`users: User[]`, not `userList`/`user`).
     Flag singular/plural mismatches and singular names holding many.

5. Conventions & casing
   - Follow the language's and project's established casing conventions consistently (in TS/JS:
     camelCase vars, PascalCase types; in Python: snake_case functions, PascalCase classes,
     UPPER_SNAKE constants; in Go: exported PascalCase / unexported camelCase, short receiver
     names; in Rust: snake_case fns, CamelCase types). Type params are meaningful or conventional —
     flag noise like `T1`, `Type` (in TS, the conventional `T`/`K`/`V` are fine). Avoid
     type-vs-value name collisions for distinct concepts.
   - Follow the framework's naming conventions where one applies (NestJS provider/DTO suffixes
     `*Service`/`*Repository`/`*Controller`/`CreateUserDto`/`UserEntity` and descriptive injection
     tokens like `USER_REPOSITORY`; Vue composables `useX`, multi-word PascalCase components,
     camelCase `props`/`emits`, past-tense events or `update:modelValue` for `v-model`; Spring
     `*ServiceImpl`, Rails model/controller conventions, Go package-qualified names). Flag breaks
     from whatever convention the project has adopted.

6. Consistency & file agreement
   - The same concept has the same name everywhere. Flag two names for one idea (and one name
     for two ideas), and a file/symbol whose name disagrees with what it exports. Avoid
     abbreviations that hurt code search.

Report per the output contract. When a comment exists only to explain a bad name, the fix is a
rename, not a comment — note that.
