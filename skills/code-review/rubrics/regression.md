# Track: regression (static risk analysis)

Lens: what could this change break? Reason about risk from the diff — do **not** run anything
here (that's the `regression-check` track).
Primary stack: NestJS, Vue 3, Pinia, TypeScript. The framework-specific items below (Nest DI,
Pinia, TypeORM) are examples of the underlying risks — **apply the same reasoning to whatever
stack the diff is in.** For a backend/data-pipeline change in another language (a Java indexer,
a Go service), the highest-value risks are usually items 2–6 below: invariants that must hold
across a batch (counts that must reconcile, "every item lands in exactly one bucket"),
retry/idempotency under at-least-once delivery, ordering/shutdown races (does a late write race a
swap/commit?), and numeric edge cases (overflow to ∞, NaN, clamping). Hold those to the same bar
as the framework items.

Check, in priority order:

1. Changed contracts
   - Modified public surfaces: API routes, method signatures, DTOs, response shapes, emitted
     events. For each, who consumes it and what breaks? Watch optional→required fields, a removed
     or renamed field, and a narrowed type. Event/message payloads: is the shape versioned, or do
     in-flight consumers see the new shape?
   - **Find the real call sites — don't guess them.** When a public signature, field, type, or
     default changes, use the built-in `LSP` tool (`findReferences`, `incomingCalls`,
     `goToDefinition`) to enumerate the *actual* usages across the repo before claiming blast
     radius. Turn "this might break callers" into "this breaks these N call sites: …", and catch the
     update site the author missed. Fall back to `ast-grep`/grep only when no language server is
     available. See `tool-registry.md`.

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
   - Security-shaped risks (injection, secrets, vulnerable deps, auth widening): if the `security`
     track is also running this review, defer them to it (flag there, not here, to avoid
     double-reporting). If `security` is **not** selected, do **not** drop them — raise them here so
     they aren't silently lost; note that a dedicated `security` pass would go deeper.

8. Framework blast radius
   - NestJS: guards, interceptors, pipes, filters, or middleware that affect many routes; a changed
     middleware/interceptor order; DI scope (REQUEST vs DEFAULT) and global vs module-scoped
     providers — a provider that becomes shared (or per-request) changes state lifetime everywhere.
   - Vue/Pinia: a store mutation/getter or shared composable signature that many components consume;
     prop/emit contract changes; a changed `provide`/`inject` key or its value shape.

Report per the output contract. For each risk, state the blast radius, how to verify it, and
the specific test worth adding.
