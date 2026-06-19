# Track: regression-check (dynamic — runs the suite)

Lens: does the project's own tooling pass on this change? This track executes commands; the
others don't.
Stack: NestJS, Vue 3, TypeScript.

Procedure:

1. Discover the real scripts
   - Read the root `package.json` and use its actual `scripts`. Do not assume script names.
   - Detect a workspace/monorepo: a `workspaces` field, `pnpm-workspace.yaml`, or a tool
     like Nx/Turborepo. If present, expect a separate backend (Nest) and frontend (Vue)
     package, each with its own `scripts`. Read each touched package's `package.json` too.
   - Use the repo's package manager (lockfile decides: `pnpm-lock.yaml` → pnpm,
     `yarn.lock` → yarn, else npm). Match its workspace flags (`pnpm -F <pkg>`,
     `yarn workspace <pkg>`, `npm -w <pkg>`).

2. Scope the run to what changed
   - Map the diff's files to their owning package(s). Run the suite only for those packages —
     run the backend scripts if backend files changed, the frontend scripts if frontend files
     changed, both if both. Don't run the whole monorepo when one package changed.
   - If the repo exposes an affected/changed filter (Nx `affected`, Turborepo `--filter`),
     use it to scope further.

3. Run, per affected package, in this order whichever exist (via the shell):
   - type check (e.g. `tsc --noEmit` or the package's `typecheck` script)
   - lint (e.g. its `lint` script)
   - unit tests (e.g. its `test` script)
   - e2e tests if present (e.g. its `test:e2e` script)
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
