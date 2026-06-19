# Tool registry — the deterministic layer

This file is the source of truth for the **open-source analyzers** the review runs to gather
ground-truth findings before the LLM reasons. It is shared by the `security` track (which depends
on it) and consulted by `regression`/`regression-check` for blast-radius and suite runs.

The model on a diff is blind to a specific set of facts: cross-file taint, who actually calls a
changed symbol, whether a leaked key is live, and which transitive dependency carries a CVE. These
tools fill exactly those gaps. **Every tool here is OSS and runnable locally with no account.**

## The two-stage contract (do not skip stage 2)

1. **Gather** — run whichever tools below are runnable, scoped to the diff. Collect raw findings as
   `tool | path:line | rule-id | severity | message`. Never put raw analyzer output in the report.
2. **Triage** — the LLM takes that structured list *plus the diff* and:
   - drops false positives (OSS analyzers are noisy — Semgrep CE alone runs ~70% FP on some rule
     packs; a finding you can't confirm in the diff is a candidate to drop, said as much),
   - dedupes against findings the tracks already raised (report once, cite the tool as corroboration),
   - maps each surviving finding to this skill's severity (`output-format.md`) and explains *why* it
     matters here, not just the rule name.
   A tool finding the model cannot tie to a concrete line/risk is noise — say "N raw findings, M
   survived triage" so the drop is visible, never silently swallowed.

## Running the tools — ephemeral-first, then graceful skip

For each tool, try invocations in this order and stop at the first that works:

1. **Already in PATH** (`command -v <tool>`) → use it directly. Fastest, no network.
2. **Ephemeral runner** — run without a persistent install:
   - Python tools → `uvx <tool>` (or `pipx run <tool>`)
   - Node tools → `npx --yes <tool>`
   - Anything with an image → `docker run --rm -v "$PWD:/src" <image>`
   Give the ephemeral attempt a **short timeout (~60s)** — first run fetches the package/image.
3. **Skip, on the record** — if neither works (offline, no runner, timeout), do **not** fabricate
   results. Note it in the report: `<tool> scan skipped — not installed and ephemeral run
   unavailable (install: <one-liner>)`. The track still runs its LLM reasoning; it just loses that
   tool's corroboration.

Always scope to the change, never the whole repo — whole-repo output buries the diff's signal.

## The tools

### SAST — Semgrep (CE)
- **Catches:** injection sinks, weak crypto, unsafe deserialization, CWE patterns across 30+ langs —
  deterministic matches the model overlooks while reading prose.
- **Run:** `semgrep scan --config p/security-audit --metrics=off --sarif --output semgrep.sarif
  <changed-paths>`. Use a pinned registry pack (`p/security-audit`), not `--config auto` — `auto`
  resolves rules from the network per-run and pings telemetry, which breaks the "local, no-account"
  promise; `--metrics=off` disables the telemetry ping. Any registry pack still fetches its rules on
  first run (cached after), so a fully air-gapped run needs a local rules path (`--config
  ./rules.yml`) or skips on the record. Ephemeral: `uvx semgrep ...` / `docker run --rm -v
  "$PWD:/src" ghcr.io/semgrep/semgrep semgrep ...`.
- **Diff-scope:** pass only the changed files; or `semgrep ci --baseline-commit <merge-base>` to
  report only newly-introduced findings.
- Parse the SARIF `runs[].results[]` → `ruleId`, `level`, `locations[].physicalLocation`.

### Secrets — Gitleaks (+ built-in fallback)
- **Catches:** API keys/tokens/high-entropy strings in the **commit range and git history**, which
  the patch text alone doesn't reveal.
- **Run:** `gitleaks git --log-opts="<merge-base>..HEAD" --report-format json --report-path
  gitleaks.json` (staged working tree: `gitleaks git --staged` — the `protect` subcommand is
  deprecated). Ephemeral: `docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks git
  --log-opts=...`.
- **Built-in fallback (PR-scope only):** the GitHub MCP `run_secret_scanning` tool scans raw diff
  hunks for secrets — available only when reviewing a GitHub PR. For a local working-diff or path
  scope there is no MCP fallback: use Gitleaks (ephemeral) or skip on the record.
- A confirmed live/committed secret is a **Blocker**, full stop.

### Dependencies & licenses — Trivy / osv-scanner
- **Catches:** transitive-dependency CVEs and disallowed licenses — there is no advisory DB in the
  model's head, so this is a categorical blind spot, not an unreliable one.
- **Gate on a manifest change first.** Run this scanner *only* when the diff touched a
  manifest/lockfile (`package.json`/lockfile, `pom.xml`, `go.mod`, `Cargo.toml`, `requirements.txt`,
  etc.). If no dependency file changed, skip it — there's no new dependency risk to find, and a
  whole-repo scan would only surface pre-existing CVEs that aren't this PR's regression.
- **Run** (these scanners resolve the whole dependency graph by design — that's correct here, since a
  bumped lockfile can change transitive deps; the manifest-change gate above is what scopes them to
  the PR): `trivy fs --scanners vuln,license --format json --quiet .` (ephemeral: `docker run --rm
  -v "$PWD:/src" aquasec/trivy fs ...`), or `osv-scanner --format json --download-offline-databases
  --offline .` (the `--download-offline-databases` + `--offline` pair is the documented form:
  fetch the DB once this run, then evaluate with no further network).
- A pre-existing CVE in a dependency the PR didn't touch is not this PR's regression — note it as
  pre-existing at most, don't count it against the change.

### Blast radius — LSP (built-in) / ast-grep
- **Catches:** the real call sites of a changed symbol — stops the model guessing or staying silent
  on who a signature/field/type change breaks. This is the single biggest correctness upgrade for
  the `regression` and `architecture` tracks.
- **Run:** the built-in `LSP` tool — `findReferences` (every usage), `goToDefinition`,
  `incomingCalls`/`outgoingCalls` (call hierarchy) on a changed symbol. No install if a language
  server is configured for the file type.
- **Fallback:** `ast-grep` for structural "is this pattern used elsewhere" when no LSP is available
  (pattern-match, not type-aware — weaker, but install-free via `npx --yes @ast-grep/cli`).
- Use it whenever a finding's correctness depends on facts outside the hunk: changed/removed public
  signatures, deleted/renamed symbols, narrowed types, changed defaults/enums. Skip it for
  within-hunk logic (off-by-one, null check) — there it adds nothing.

### Diff-scoping glue — reviewdog (optional)
- **Catches nothing itself** — it maps *any* analyzer's output onto the changed lines
  (`-filter-mode=added`) and emits structured `rdjson` the model consumes directly. Use it to turn a
  Bash pipeline of the tools above into diff-scoped findings instead of whole-repo noise.
- **Run:** `<tool> | reviewdog -f=<format> -filter-mode=added -reporter=local`. Optional — when
  absent, scope by passing changed paths to each tool directly.

### Native type/compiler-aware linter — owned by `regression-check`
- **Catches:** type-precise bugs the model can't see without the whole project's types — floating
  promises, stdlib misuse, exhaustiveness gaps.
- **Ownership (avoids a double run):** the native linter is run by the **`regression-check`** track,
  not by the security gather — it's the project's own tooling, detected and invoked there
  (typescript-eslint, `staticcheck`/`golangci-lint`, `cargo clippy`, Roslyn, `ruff`). The gather
  stage does **not** run it. Other tracks that want its output read it from the `regression-check`
  run if that track is selected; otherwise they reason without it. One owner, one run.

## Cost discipline

Run the tools **once per review**, in parallel where independent, scoped to the diff. Don't re-run
per track. If the diff is large and tracks are fanned out to subagents (see `SKILL.md`), run the
gather stage once in the orchestrator and pass the findings down — don't have every subagent
re-scan.
