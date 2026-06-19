# Track: regression (static risk analysis)

Lens: what could this change break? Reason about risk from the diff — do **not** run anything
here (that's the `regression-check` track).
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Changed contracts
   - Identify modified public surfaces: API routes, method signatures, DTOs, response shapes,
     emitted events. For each, who consumes it and what breaks?

2. Backward compatibility
   - Breaking changes for other modules, the frontend, or external clients. DB schema /
     migration risk. Serialization or payload-shape changes.

3. Edge cases
   - Newly exposed or unhandled: null/empty/boundary values, concurrency and ordering,
     timezones, large inputs, pagination limits.

4. Side effects & shared state
   - Does the change touch caches, global config, shared services, or singletons? Flag effects
     that reach beyond the changed unit.

5. Error-path changes
   - Does it change which errors are thrown, caught, or surfaced to callers?

6. Test coverage of the change
   - Are the modified branches covered by existing tests? Identify changed paths with no
     coverage and the specific case a new test should assert.

7. Framework blast radius
   - NestJS: changes to guards, interceptors, pipes, or DI scope that affect many routes.
     Vue: store mutations or shared composables that many components depend on.

Report per the output contract. For each risk, state the blast radius, how to verify it, and
the specific test worth adding.
