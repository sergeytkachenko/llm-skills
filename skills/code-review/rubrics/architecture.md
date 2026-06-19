# Track: architecture (Clean Architecture)

Lens: does this change keep boundaries clean and dependencies pointing the right way?
Stack: NestJS (backend), Vue 3 + Pinia (frontend), TypeScript throughout.

Check, in priority order:

1. Dependency direction
   - Dependencies point toward abstractions, not concretions. Domain / business logic must
     not import infrastructure (DB clients, ORMs, HTTP libraries, framework internals).
   - Flag a controller or component importing a DB client, repository implementation, or
     calling `fetch`/axios directly. Prefer an injected interface / repository token.

2. Layer boundaries
   - NestJS: controllers stay thin (HTTP concerns only) — no business logic, no direct data
     access. Business logic lives in services; persistence in repositories/providers.
   - Vue 3: components handle presentation. Logic belongs in composables; server and shared
     state in Pinia stores. Flag data-fetching or business rules embedded in `.vue` files,
     and prop-drilling more than ~2 levels where a store or provide/inject fits better.

3. Module boundaries & DI graph
   - NestJS: a module's surface is its `exports`. Flag providers consumed across modules but
     not exported (reaching past the boundary), and internals/types leaking through exports.
   - Flag circular DI between modules and `forwardRef`/circular `imports` introduced to paper
     over it — prefer splitting the shared concern out or inverting via an interface token.
   - `forRoot`/`forFeature` dynamic modules: config/secrets enter here, not via globals.
   - Pinia: flag store-to-store cycles and a store mutating another store's state directly
     (call its actions instead). Composables depend downward (composable → store), never the
     reverse.

4. Coupling & cohesion
   - Each module/service has one reason to exist. Flag god-services, modules that reach into
     everything, and shared "util/common" buckets that quietly become a dependency hub.

5. SOLID at module level
   - SRP per provider/module; DIP via DI tokens / interfaces rather than newing concrete
     classes; extension points open for extension, closed for modification.

6. Contracts at the edges
   - DTOs + validation at the boundary; domain types stay internal. Flag ORM entities leaking
     into responses, and missing validation at the system edge (controller params, message
     payloads, external API responses).

7. Cross-cutting concerns
   - Auth, logging, transactions, error mapping, caching belong in guards / interceptors /
     filters / pipes (Nest) or plugins / composables (Vue) — not hand-rolled inline in each
     handler. Flag a concern copy-pasted across handlers instead of factored to a seam.

8. Transaction & async seams
   - One unit of work per use case: flag a service opening multiple independent transactions
     for what should be one atomic operation, or a transaction held open across a remote/HTTP
     call.
   - Flag fire-and-forget side effects mid-request (unawaited promises) and synchronous work in
     the request path that belongs on an event/queue seam. Domain events emit after commit.

9. Side effects & I/O
   - I/O and effects isolated at the edges; the core stays as pure as practical. Flag hidden
     I/O inside otherwise-pure logic.

Report per the output contract. This is a structural pass — defer micro-naming, comment, and
function-shape issues to the `naming`, `comments`, and `clean-code` tracks.
