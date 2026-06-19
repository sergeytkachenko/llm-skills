# Tool registry — the deterministic layer

This file is the source of truth for the **open-source analyzers** the review runs to gather
ground-truth findings before the LLM reasons. It is shared by the `security` track (which depends
on it) and consulted by `regression`/`regression-check` for blast-radius and suite runs.

The model on a diff is blind to a specific set of facts: cross-file taint, who actually calls a
changed symbol, whether a leaked key is live, and which transitive dependency carries a CVE. These
tools fill exactly those gaps. **Every tool here is OSS and needs no account.** They run locally in
containers, but three of the four (Semgrep, Trivy, osv-scanner) fetch rule packs / vuln databases
over the network on their *first* run, then cache them (image-pinned or in a named volume) for
offline reuse — only Gitleaks is fully offline from the start. A first run on an air-gapped host
therefore degrades to a per-tool skip on the record (see below); it is not "fully offline" out of
the box.

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

## Running the tools — Docker Compose only

The skill brings its **own** pinned toolchain. Every analyzer runs as a container defined in
[`../tools/compose.yml`](../tools/compose.yml) — **never** from the host PATH, `uvx`, or `npx`.
This makes the gather stage reproducible and versioned: the same image tags yield the same findings
on any machine with Docker. There is exactly one invocation mechanism — no host-install path, no
ephemeral fallback to maintain.

**Invocation.** The code under review mounts read-only at `/src`; reports go to a **separate
writable** mount `/out` (never into `/src` — `/src` is read-only by design). Set the three env vars,
create the output dir on the host, and `run --rm` the service:

```
# Locate the compose file relative to THIS skill, not a hardcoded cache path.
# ${CLAUDE_PLUGIN_ROOT} is exported by the harness for a plugin skill; fall back
# to resolving from the rubric's own location if it isn't set.
COMPOSE="${CLAUDE_PLUGIN_ROOT:?}/skills/code-review/tools/compose.yml"
[ -f "$COMPOSE" ] || COMPOSE="$(cd "$(dirname "$0")/.." && pwd)/tools/compose.yml"

REVIEW_DIR="$(pwd)"                          # repo working tree, or the PR worktree path
OUTPUT_DIR="$(mktemp -d)"                    # reports land OUTSIDE the reviewed tree
GIT_COMMON_DIR="$(git -C "$REVIEW_DIR" rev-parse --path-format=absolute --git-common-dir)"  # abs path; see Secrets

REVIEW_DIR="$REVIEW_DIR" OUTPUT_DIR="$OUTPUT_DIR" GIT_COMMON_DIR="$GIT_COMMON_DIR" \
  docker compose -f "$COMPOSE" run --rm <service> <args writing to /out/…>
```

Read each report back from `$OUTPUT_DIR/`. Writing reports to a `mktemp -d` outside `$REVIEW_DIR`
(not `$REVIEW_DIR/.review`) means there is **nothing to clean up inside the reviewed tree** and no
risk of leaking `.review/` into the user's checkout or a PR worktree. Remove `$OUTPUT_DIR` when the
review ends; because it's a temp dir, an aborted review leaves nothing in the user's repo.

**Resolving the compose path:** prefer `${CLAUDE_PLUGIN_ROOT}` (the harness exports it for a plugin
skill); only fall back to a relative resolve. Do **not** hardcode a `~/.claude/plugins/cache/...`
path — the version segment and plugin/marketplace names change.

**Preflight + skip — per service, not all-or-nothing.** Before gather, once: `docker compose
version` (Docker CLI present?) and `docker info` (daemon up?). If Docker/Compose is unavailable,
skip the **whole** deterministic layer on the record. But Docker being present is *not* a guarantee
each tool runs — so treat each service's failure independently:

- A service whose image won't pull, whose first-run DB/rule fetch is blocked (no egress), or that
  errors out → **skip that one tool on the record** (`<tool> scan skipped — <reason>`), and keep the
  others. One blocked scanner must not silently pass as "scanned clean", and must not kill the rest.
- Give the first `compose run` of each service a longer timeout (~120s — first run pulls the image /
  warms its cache volume); later runs are fast. A timeout is a per-tool skip, not a layer failure.
- Never fall back to a host binary, never fabricate results. The verdict states which services ran
  and which were skipped (per `output-format.md`).

**Parallelism — opt in explicitly.** Separate `compose run` containers *can* run at once, but each
call blocks, so the gather step must launch the independent services concurrently (background the
Bash calls / run them in one batch) and then join — they do **not** overlap automatically. Don't
issue them strictly serially and call it "concurrent".

Always scope to the change, never the whole repo — whole-repo output buries the diff's signal.

## The tools

### SAST — Semgrep (CE)
- **Catches:** injection sinks, weak crypto, unsafe deserialization, CWE patterns across 30+ langs —
  deterministic matches the model overlooks while reading prose.
- **Run** (compose service `semgrep`):
  `docker compose -f "$COMPOSE" run --rm semgrep scan --config p/security-audit --metrics=off
  --sarif --output /out/semgrep.sarif <changed-paths-relative-to-/src>`.
  Use a pinned registry pack (`p/security-audit`), not `--config auto` — `auto` resolves rules from
  the network per-run and pings telemetry; `--metrics=off` disables the telemetry ping. The pack
  fetches its rules over the network on first run and caches them in the `semgrep-cache` volume
  (subsequent runs are offline); a fully air-gapped *first* run needs a local rules path mounted into
  `/src` (`--config /src/rules.yml`) or skips on the record.
- **Diff-scope:** pass only the changed files (paths under `/src`). The `semgrep ci
  --baseline-commit` form needs git history in the container, which the plain `/src` mount may not
  carry for a linked worktree (see Secrets below) — prefer passing changed paths explicitly.
- Read the SARIF back from `$OUTPUT_DIR/semgrep.sarif`; parse `runs[].results[]` → `ruleId`,
  `level`, `locations[].physicalLocation`.

### Secrets — Gitleaks (+ built-in fallback)
- **Catches:** API keys/tokens/high-entropy strings in the **commit range and git history**, which
  the patch text alone doesn't reveal.
- **Run** (compose service `gitleaks`, fully offline):
  `docker compose -f "$COMPOSE" run --rm -e GIT_DIR=/gitcommon gitleaks git /src
  --log-opts="<merge-base>..HEAD" --report-format json --report-path /out/gitleaks.json`
  (staged working tree: `... gitleaks git /src --staged ...` — the `protect` subcommand is
  deprecated). Read the report from `$OUTPUT_DIR/gitleaks.json`.
  - **Why `GIT_DIR=/gitcommon`:** gitleaks `git` mode needs the commit objects. In a **linked
    worktree** (the default for a PR review, `git worktree add`), `$REVIEW_DIR/.git` is a *pointer
    file* and the object store lives in the parent repo — *outside* the mounted `/src`. The compose
    file mounts `git rev-parse --git-common-dir` (the real object store) read-only at `/gitcommon`,
    and `GIT_DIR=/gitcommon` points gitleaks at it. For a normal (non-worktree) repo,
    `--git-common-dir` is just `$REVIEW_DIR/.git`, so this is a harmless re-mount.
- **Built-in fallback — only when the Gitleaks service can't run.** On a GitHub PR review where
  Docker is unavailable (so the whole compose layer skipped), the GitHub MCP `run_secret_scanning`
  tool scans the raw diff hunks — a *reduced* check (patch text only, no history), but better than
  nothing. It is **not** a routine alternative: when Gitleaks ran, don't also run it. For a local /
  path scope there is no MCP fallback — skip on the record.
- A confirmed live/committed secret is a **Blocker**, full stop.

### Dependencies & licenses — Trivy / osv-scanner
- **Catches:** transitive-dependency CVEs and disallowed licenses — there is no advisory DB in the
  model's head, so this is a categorical blind spot, not an unreliable one.
- **Gate on a manifest change first.** Run this scanner *only* when the diff touched a
  manifest/lockfile (`package.json`/lockfile, `pom.xml`, `go.mod`, `Cargo.toml`, `requirements.txt`,
  etc.). If no dependency file changed, skip it — there's no new dependency risk to find, and a
  whole-repo scan would only surface pre-existing CVEs that aren't this PR's regression.
- **Run** (compose service `trivy` or `osv-scanner` — these resolve the whole dependency graph by
  design, which is correct here since a bumped lockfile can change transitive deps; the
  manifest-change gate above is what scopes them to the PR):
  `docker compose -f "$COMPOSE" run --rm trivy fs --scanners vuln,license --format json --quiet
  --output /out/trivy.json /src`, or
  `docker compose -f "$COMPOSE" run --rm osv-scanner --format json --output /out/osv.json
  --download-offline-databases --offline /src` (the `--download-offline-databases` + `--offline`
  pair is the documented form: fetch the DB once this run, then evaluate with no further network).
  Both services keep their vuln DB in a named cache volume, so the download is a one-time cost. Read
  the reports from `$OUTPUT_DIR/`.
- A pre-existing CVE in a dependency the PR didn't touch is not this PR's regression — note it as
  pre-existing at most, don't count it against the change.

### Blast radius — LSP (built-in) / Grep
- **Catches:** the real call sites of a changed symbol — stops the model guessing or staying silent
  on who a signature/field/type change breaks. This is the single biggest correctness upgrade for
  the `regression` and `architecture` tracks.
- **Run:** the built-in `LSP` tool — `findReferences` (every usage), `goToDefinition`,
  `incomingCalls`/`outgoingCalls` (call hierarchy) on a changed symbol. No install if a language
  server is configured for the file type.
- **Fallback:** plain Grep for structural "is this pattern used elsewhere" when no language server
  is available (text-match, not type-aware — weaker, but always available). The LSP and Grep are the
  built-in exceptions to the compose-only rule: they are session tools, not analyzers in the
  toolchain, so they don't run in a container.
- Use it whenever a finding's correctness depends on facts outside the hunk: changed/removed public
  signatures, deleted/renamed symbols, narrowed types, changed defaults/enums. Skip it for
  within-hunk logic (off-by-one, null check) — there it adds nothing.

### Diff-scoping — done by the model, not a tool
- The analyzers above are already scoped at the command (changed paths to Semgrep, the commit range
  to Gitleaks, the manifest-change gate to Trivy/osv). After reading a report, the model further
  drops any finding whose `path:line` falls outside the diff hunks — that filtering is part of the
  triage stage, not a separate container. (No `reviewdog` service: it would add a tool to the
  compose-only toolchain for what the triage step already does.)

### Native type/compiler-aware linter — owned by `regression-check`
- **Catches:** type-precise bugs the model can't see without the whole project's types — floating
  promises, stdlib misuse, exhaustiveness gaps.
- **Ownership (avoids a double run):** the native linter is run by the **`regression-check`** track,
  not by the security gather — it's the project's own tooling, detected and invoked there
  (typescript-eslint, `staticcheck`/`golangci-lint`, `cargo clippy`, Roslyn, `ruff`). The gather
  stage does **not** run it. Other tracks that want its output read it from the `regression-check`
  run if that track is selected; otherwise they reason without it. One owner, one run.

## Cost discipline & cleanup

Run the tools **once per review**, scoped to the diff. Don't re-run per track. The independent
services *can* overlap, but only if the gather step launches them concurrently and joins (see
"Parallelism" above) — they don't overlap on their own. If the diff is large and tracks are fanned
out to subagents (see `SKILL.md`), run the gather stage once in the orchestrator and pass the
findings down — don't have every subagent re-scan.

Reports land in `$OUTPUT_DIR` — a `mktemp -d` **outside** the reviewed tree, never inside `$REVIEW_DIR`.
So there is nothing to clean up in the user's checkout or a PR worktree, and an aborted review leaks
nothing into their repo. Remove `$OUTPUT_DIR` when the review ends (`rm -rf "$OUTPUT_DIR"`); since
it's a temp dir, even a forgotten cleanup lands in the OS temp space, not the working tree.
