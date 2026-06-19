# Track: regression-check (dynamic — runs the suite)

Lens: does the project's own tooling pass on this change? This track executes commands; the
others don't.
Primary stack: NestJS, Vue 3, TypeScript — but **detect the actual stack from the repo, don't
assume it.** The discovery rules below are stack-agnostic; step 1 maps the build tool to its
commands.

Procedure:

1. Discover the build tool and the real commands — from the repo, never from memory
   - **Identify the stack from the files present, then use that tool's runner:**
     - `package.json` → Node. Read its `scripts`; pick the package manager from the lockfile
       (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm). In a workspace, scripts often live
       in the **sub-packages**, not the root — read each touched package's own `package.json` too,
       or you'll wrongly conclude "no test script" and skip the suite.
     - `pom.xml` → Maven (`mvn test`, `mvn -q verify`); `build.gradle(.kts)` → Gradle
       (`./gradlew test`). Check the POM/build file for a test-tag/profile split (e.g. a
       JUnit `@Tag("unit")` set wired via Surefire `<groups>`, or a `run-all-tests` profile)
       and run the unit set the PR claims, not the heavyweight integration/E2E set.
     - `go.mod` → `go test ./...`; `Cargo.toml` → `cargo test`; `pyproject.toml`/`setup.cfg` →
       `pytest` (or the configured runner); `*.csproj`/`*.sln` → `dotnet test`.
     - Mixed repo → run the tool for each touched language.
   - **Honour the right JDK / runtime / toolchain.** If the build pins a version (POM
     `maven.compiler.target`, `.tool-versions`, `.nvmrc`, `go` directive), use it. If you can't
     match it, say so and report the version you actually ran on — a green run on the wrong
     toolchain is not the claim being verified.
   - **Cross-check the PR's own test claim.** If the description cites a count or "all pass",
     run the same set it names and compare. A real 142 against a claimed 146 is a finding
     (Major) for the claim-verification step in `SKILL.md`, not just a passing run.
   - Detect a workspace/monorepo (Node `workspaces`/`pnpm-workspace.yaml`/Nx/Turborepo; Maven
     reactor; Gradle multi-project) and scope per module (step 2). Invoke a single package's scripts
     with the manager's workspace flag — `pnpm -F <pkg> <script>`, `yarn workspace <pkg> <script>`,
     `npm -w <pkg> run <script>` (Maven `-pl <module>`, Gradle `:<module>:<task>`) — don't run the
     whole monorepo when one package changed.

2. Scope the run to what changed
   - Map the diff's files to their owning package(s). Run the suite only for those packages —
     run the backend scripts if backend files changed, the frontend scripts if frontend files
     changed, both if both. Don't run the whole monorepo when one package changed.
   - If the repo exposes an affected/changed filter (Nx `affected`, Turborepo `--filter`),
     use it to scope further.

3. Run, per affected package/module, in this order whichever exist (via the shell):
   - compile / type check (Node `tsc --noEmit` or a `typecheck` script; Maven/Gradle compile;
     `go build`; `cargo check`; `dotnet build`)
   - lint / static analysis if the repo configures one (a `lint` script, `golangci-lint`,
     `ruff`, etc.). This track **owns** the native type/compiler-aware linter (per
     `tool-registry.md`) — the gather stage does not run it, so there's no double run; other tracks
     read your output if they need it.
   - unit tests (the fast, isolated set — Node `test` script; `mvn test` unit-tag set;
     `go test ./...`; `pytest`)
   - integration / e2e tests if present **and runnable** (Node `test:e2e`; a Maven
     `run-all-tests`/integration profile; anything behind Testcontainers/a live service). If a
     step needs infra you don't have (a database, Elasticsearch, Docker), don't fake it — note
     it as not run and why, and run the rest.
   - For a long suite, prefer scoping to the changed package/test files over running
     everything; say what you scoped to and what you skipped.

4. Report — only what actually happened
   - Show only failures and warnings, never the passing output. Group by package + command.
   - Quote the real tool output. Never invent, paraphrase loosely, or guess at output you
     did not see.
   - For each failure, map it to the offending `path:line` and the likely cause from the diff.
   - Distinguish regressions from pre-existing failures: if a failure is unrelated to the
     diff (touches files the change never modified, or reproduces on the base ref), label it
     pre-existing and don't count it against the change. Only diff-caused failures are
     regressions.
   - If coverage is configured, note changed files with missing or low coverage.

5. Handle the messy cases
   - No runner/script present for a step → say so plainly and suggest the script that should
     exist. Don't fabricate a pass or a fail.
   - Flaky or timed-out run → re-run once; if it still won't settle, report it as flaky/timeout
     (not a clean failure) and say which command and how long.
   - Partial run (you stopped early, scoped down, or a step couldn't start) → state exactly
     what ran, what didn't, and why, so the verdict isn't read as full coverage.

Report per the output contract. Do not fix failures unless the invocation included `--fix`; when
it did, fix the smallest cause, then re-run the failed command to confirm.
