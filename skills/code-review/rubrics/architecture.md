# Track: architecture (Clean Architecture)

Lens: does this change keep boundaries clean and dependencies pointing the right way?
Stack: NestJS (backend), Vue 3 + Pinia (frontend), TypeScript throughout.

Check, in priority order:

1. Dependency direction
   - Dependencies point toward abstractions, not concretions. Domain / business logic must
     not import infrastructure (DB clients, ORMs, HTTP libraries, framework internals).
   - Flag a controller or component importing a DB client, repository implementation, or
     calling `fetch`/axios directly.

2. Layer boundaries
   - NestJS: controllers stay thin (HTTP concerns only) — no business logic, no direct data
     access. Business logic lives in services; persistence in repositories/providers.
   - Vue 3: components handle presentation. Logic belongs in composables; server and shared
     state in Pinia stores. Flag data-fetching or business rules embedded in `.vue` files.

3. Coupling & cohesion
   - Each module/service has one reason to exist. Flag god-services, modules that reach into
     everything, and circular dependencies between modules.

4. SOLID at module level
   - SRP per provider/module; DIP via DI tokens / interfaces rather than newing concrete
     classes; extension points open for extension, closed for modification.

5. Contracts at the edges
   - DTOs + validation at the boundary; domain types stay internal. Flag ORM entities leaking
     into responses, and missing validation at the system edge.

6. Side effects & I/O
   - I/O and effects isolated at the edges; the core stays as pure as practical. Flag hidden
     I/O inside otherwise-pure logic.

Report per the output contract. This is a structural pass — defer micro-naming and comment
issues to the `naming` and `comments` tracks.
