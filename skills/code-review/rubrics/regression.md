# Track: regression (static risk analysis)

Lens: what could this change break? Reason about risk from the diff — do **not** run anything
here (that's the `regression-check` track).
Stack: NestJS, Vue 3, Pinia, TypeScript.

Check, in priority order:

1. Changed contracts
   - Modified public surfaces: API routes, method signatures, DTOs, response shapes, emitted
     events. For each, who consumes it and what breaks? Watch optional→required fields, a removed
     or renamed field, and a narrowed type. Event/message payloads: is the shape versioned, or do
     in-flight consumers see the new shape?

2. Backward compatibility
   - Breaking changes for other modules, the frontend, or external clients.
   - DB migrations: is it reversible (down works)? A new non-nullable column without a default or
     backfill breaks existing rows and concurrent writes. Adding/dropping an index or altering a
     large table — lock and downtime risk. Flag any data migration with no backfill plan.
   - Serialization drift: Date/ISO-string, decimal vs number, bigint, enum casing, null vs absent
     key. A changed default value or a new enum/union member that downstream `switch`/exhaustive
     checks don't handle.

3. Edge cases
   - Newly exposed or unhandled: null/empty/boundary values, timezones, large inputs.
   - Concurrency: race conditions, lost updates, non-idempotent handlers that retries/at-least-once
     delivery will double-apply.
   - Ordering & pagination: a changed sort key or unstable sort shifts results; changed
     page-size/limit/offset or cursor semantics break callers paging through.

4. Side effects & shared state
   - Does the change touch caches, global config, shared services, or singletons? Cache key or TTL
     changes — stale reads, poisoned entries, or a cache that no longer invalidates on write.
   - Feature-flag / config / env-var defaults: a new env var with no default, or a flipped default,
     changes behavior in environments not in the diff.
   - N+1: a query moved into a loop or a lazy relation now hit per-row.

5. Auth & permissions
   - Changes to a guard, role check, ownership filter, or permission scope. Does it widen access,
     drop a tenant/owner filter, or change who can reach a route?

6. Error-path changes
   - Does it change which errors are thrown, caught, or surfaced to callers? A swallowed error,
     a changed status code, or a new throw on a previously total path.

7. Test coverage of the change
   - Are the modified branches covered by existing tests? Identify changed paths with no coverage
     and the specific case a new test should assert.

8. Framework blast radius
   - NestJS: guards, interceptors, pipes, filters, or middleware that affect many routes; a changed
     middleware/interceptor order; DI scope (REQUEST vs DEFAULT) and global vs module-scoped
     providers — a provider that becomes shared (or per-request) changes state lifetime everywhere.
   - Vue/Pinia: a store mutation/getter or shared composable signature that many components consume;
     prop/emit contract changes; a changed `provide`/`inject` key or its value shape.

Report per the output contract. For each risk, state the blast radius, how to verify it, and
the specific test worth adding.
