# Track: architecture (Clean Architecture)

Lens: does this change keep boundaries clean and dependencies pointing the right way?
The principles below are universal — they apply to any stack (Java/Spring, Go, Python,
Rust, .NET, Rails, …). Examples lean toward NestJS/Vue/TS but the checks are
language-agnostic.

Check, in priority order:

1. Dependency direction
   - Principle: dependencies point toward abstractions, not concretions. Domain / business
     logic must not import infrastructure (DB clients, ORMs, HTTP libraries, framework
     internals). Inner layers know nothing of outer ones.
   - Flag an entry point reaching straight for I/O instead of an injected interface /
     repository (e.g. in NestJS, a controller importing a DB client or calling `fetch`/axios
     directly; in Spring, an `@Controller` doing JDBC/JPA; in Go, an HTTP handler calling the
     `database/sql` driver; in Django, business code importing `requests` or raw `cursor`).

2. Layer boundaries
   - Principle: each layer has one kind of responsibility — transport/presentation, business
     logic, persistence — and does not bleed into the next.
   - Backend: entry points stay thin (transport concerns only), business logic lives in a
     service layer, persistence behind repositories (e.g. Nest controllers thin, logic in
     services, data in repositories/providers; Spring `@RestController` → `@Service` →
     `@Repository`; Go handler → service → store; FastAPI/Rails: no ORM queries in the
     route/controller).
   - Frontend: components handle presentation; logic and state live elsewhere (e.g. Vue 3
     logic in composables, server/shared state in Pinia — flag data-fetching or business rules
     in `.vue` files, and prop-drilling past ~2 levels where a store or provide/inject fits;
     equivalents: React hooks/context, Redux/Zustand).

3. Module boundaries & DI graph
   - Principle: a module exposes a deliberate surface and hides its internals; the dependency
     graph stays acyclic. Flag internals/types leaking through the public surface and
     consumers reaching past a boundary into something not meant to be exported (e.g. a NestJS
     provider used cross-module but absent from `exports`; a Java package-private type leaking
     via a public return; a Go unexported concern accessed through a back door).
   - Flag circular dependencies between modules and the hacks added to paper over them
     (e.g. Nest `forwardRef`/circular `imports`; Spring constructor-cycle workarounds; Go
     import cycles) — prefer splitting the shared concern out or inverting via an interface.
   - When a change to a module's public surface or a cross-module symbol drives a coupling claim,
     confirm it with the built-in `LSP` (`findReferences`/`incomingCalls`) instead of guessing the
     dependents — see `tool-registry.md`. Cite the real consumers (`LSP: N call sites across M
     modules`).
   - Config/secrets enter through a composition seam, not via globals (e.g. Nest
     `forRoot`/`forFeature`; Spring `@Configuration`/profiles; 12-factor env at the edge).
   - Frontend state graph stays acyclic too: flag store-to-store cycles and a store mutating
     another store's state directly instead of calling its actions; logic depends downward
     (composable → store), never the reverse.

4. Coupling & cohesion
   - Principle: each module/service has one reason to exist. Flag god-services, modules that
     reach into everything, and shared "util/common/helpers" buckets that quietly become a
     dependency hub (true in any language).

5. SOLID at module level
   - Principle: SRP per unit; DIP via interfaces/injection rather than newing concrete classes;
     open for extension, closed for modification (e.g. Nest DI tokens; Spring interfaces +
     `@Autowired`; Go accept-interfaces-return-structs; .NET `IServiceCollection`).

6. Contracts at the edges
   - Principle: validate and translate at the boundary; keep domain types internal. Flag
     persistence/ORM entities leaking into responses and missing validation at the system edge
     — request params, message payloads, external API responses (e.g. Nest DTOs + class-validator;
     Spring DTOs + Bean Validation; Go request structs + explicit validation; Pydantic models
     in FastAPI; Rails strong params).

7. Cross-cutting concerns
   - Principle: auth, logging, transactions, error mapping, caching live at a shared seam, not
     hand-rolled inline in every handler. Flag a concern copy-pasted across handlers instead of
     factored out (e.g. Nest guards/interceptors/filters/pipes; Spring filters/AOP aspects;
     Go/Express middleware; Rails `before_action`; .NET middleware/filters).

8. Transaction & async seams
   - Principle: one unit of work per use case. Flag a service opening multiple independent
     transactions for what should be one atomic operation, or a transaction held open across a
     remote/HTTP call (applies to any transaction manager — JPA/`@Transactional`, Go `*sql.Tx`,
     Django `atomic`, etc.).
   - Flag fire-and-forget side effects mid-request (unawaited promises / detached goroutines /
     background threads) and synchronous work in the request path that belongs on an
     event/queue seam. Domain events emit after commit.

9. Side effects & I/O
   - Principle: I/O and effects isolated at the edges; the core stays as pure as practical.
     Flag hidden I/O inside otherwise-pure logic (network/disk/clock/random buried in a domain
     function) — language-independent.

Report per the output contract. This is a structural pass — defer micro-naming, comment, and
function-shape issues to the `naming`, `comments`, and `clean-code` tracks.
