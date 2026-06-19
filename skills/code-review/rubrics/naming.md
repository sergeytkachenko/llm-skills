# Track: naming

Lens: does every name reveal intent and match what the thing actually does?
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Honesty
   - The name must match the behavior. Flag misleading names (a `get*` that mutates, an
     `isValid` that throws, a `fetchUser` returning cached data) and stale names left after a
     change. `async`/Promise-returning functions read as the action (`loadUser`, `saveOrder`),
     never as the resolved value.

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
   - camelCase for variables/functions, PascalCase for classes/types/Vue components,
     UPPER_SNAKE for constants. Type-param names are meaningful or the conventional `T`/`K`/`V` —
     flag noise like `T1`, `Type`. Avoid type-vs-value name collisions for distinct concepts.
   - NestJS: consistent provider suffixes (`*Service`, `*Repository`, `*Controller`), DTO/Entity/
     Schema suffixes (`CreateUserDto`, `UserEntity`), files as `*.module/service/controller.ts`,
     descriptive injection tokens (`USER_REPOSITORY`).
   - Vue: composables named `useX`; components multi-word PascalCase; `props`/`emits` camelCase;
     events past-tense or `update:modelValue` for `v-model`; template refs named `xRef`.

6. Consistency & file agreement
   - The same concept has the same name everywhere. Flag two names for one idea (and one name
     for two ideas), and a file/symbol whose name disagrees with what it exports. Avoid
     abbreviations that hurt code search.

Report per the output contract. When a comment exists only to explain a bad name, the fix is a
rename, not a comment — note that.
