# Track: regression-check (dynamic — runs the suite)

Lens: does the project's own tooling pass on this change? This track executes commands; the
others don't.
Stack: NestJS, Vue 3, TypeScript.

Procedure:

1. Discover the real scripts
   - Read `package.json` and use its actual `scripts`. Do not assume script names.

2. Run, in this order, whichever exist (via the shell):
   - type check (e.g. `npm run typecheck` or `npx tsc --noEmit`)
   - lint (e.g. `npm run lint`)
   - unit tests (e.g. `npm test`)
   - e2e tests if present (e.g. `npm run test:e2e`)

3. Report
   - Show only failures and warnings — not the passing output. Group by command.
   - For each failure, map it to the offending `path:line` and the likely cause from the diff.
   - If coverage is configured, note changed files with missing or low coverage.

4. If a command is missing
   - Say so plainly and suggest the script that should exist — don't invent or guess output.

Report per the output contract. Do not fix failures unless the invocation included `--fix`; when
it did, fix the smallest cause, then re-run the failed command to confirm.
