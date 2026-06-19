# code-review skill

A Claude Code [Skill](https://docs.claude.com/en/docs/claude-code/skills) that runs a structured
"ST code review" over your working diff (or a given path), across eight independent tracks. The
checks are **language-agnostic** — examples lean toward **NestJS + Vue 3 + TypeScript**, but the
rubrics apply to Java/Spring, Go, Python, Rust, .NET, and others, and the dynamic track detects the
repo's actual build tool.

It is **LLM + deterministic analyzers**, not LLM-alone: the tool-backed tracks (`security` for
SAST/secrets/SCA; `regression`/`architecture` for blast radius) gather ground-truth findings from
open-source tools — **Semgrep** (SAST), **Gitleaks** /
GitHub secret-scanning (secrets), **Trivy** / **osv-scanner** (dependency CVEs + licenses), and the
built-in **LSP** find-references (real call sites / blast radius) — then let the model triage them
(drop false positives, dedupe, explain). The tools catch what reading a diff misses (cross-file
taint, live secrets, CVE'd deps, who actually calls a changed function); the model makes them
usable. The analyzers run as a **pinned Docker Compose toolchain the skill ships** (`tools/compose.yml`),
so the gather stage is reproducible and versioned; if Docker isn't available the layer skips
gracefully on the record, never fabricating results.

## Tracks

| Mode | Lens |
| --- | --- |
| `architecture` | Clean Architecture — boundaries, dependency direction, layering, SOLID, contracts at the edges. |
| `clean-code` | Function/method-level — shape, complexity, DRY, magic values, error handling, TS discipline, async correctness. |
| `naming` | Intention-revealing, honest, domain-language, grammar, casing, cross-codebase consistency. |
| `comments` | Why-not-what, self-explanatory code first, dead weight, truthfulness, TODO hygiene, public-API docs. |
| `readability` | Zoom-out integrative pass — cognitive load, consistency, discoverability, coherent narrative. |
| `regression` | Static risk analysis — changed contracts, backward compat, edge cases, side effects, blast radius (uses LSP find-references for real call sites). |
| `security` | Injection/taint, secrets, auth, dependency CVEs, crypto, data exposure — LLM reasoning backed by Semgrep / Gitleaks / Trivy ground truth (see [`rubrics/tool-registry.md`](rubrics/tool-registry.md)). |
| `regression-check` | Dynamic — detects the repo's build tool (npm/pnpm/yarn, Maven, Gradle, Go, Python, .NET), runs its typecheck / lint / test / e2e, verifies any test-count claim, and reports failures. |

The output contract (severity levels, finding format, the report-only vs `--fix` rule) lives in
[`rubrics/output-format.md`](rubrics/output-format.md) and applies to every track.

## Install

This skill ships inside the `st` plugin in the [`llm-skills`](../../../../README.md) marketplace.
Add the marketplace and install the plugin (inside Claude Code):

```
/plugin marketplace add ~/projects/llm-skills
/plugin install st@st
```

It then invokes as `/st:code-review`. `git pull` in the cloned repo plus `/plugin marketplace update
st` keeps it current. The deterministic analyzer layer needs **Docker + Compose v2 on Linux or
macOS** (it runs the pinned toolchain in [`tools/compose.yml`](tools/compose.yml); a
[`preflight`](tools/preflight.sh) check validates the OS, Docker install, and a running daemon
first). Without a working Docker the skill still runs, minus that layer — never fabricating findings.

## Usage

Invoke `/code-review` with optional mode(s), an optional scope (path **or** PR URL), and an
optional `--fix`:

```
/code-review                                         # all tracks over the working diff (runs the test suite)
/code-review naming                                  # just the naming track over the working diff
/code-review naming,comments                         # two tracks
/code-review architecture src/auth                   # one track, scoped to a path
/code-review security                                # SAST + secrets + dep-CVE scan, then triage
/code-review https://github.com/org/repo/pull/2543   # review a PR in an isolated git worktree
/code-review naming,comments org/repo#2543           # tracks + a PR reference
/code-review clean-code --fix                        # apply minimal fixes for each finding
```

Argument rules:

- **Modes** — comma-separated; omit to run all tracks in canonical order. A leading `--mode` /
  `--mode=` is stripped.
- **Scope** — pick one (precedence: PR URL > path > working changes):
  - **PR URL / reference** — `https://github.com/<owner>/<repo>/pull/<n>`, `<owner>/<repo>#<n>`,
    or a bare `#<n>`. The PR is fetched and checked out into a **throwaway git worktree**
    (`.worktrees/pr-<n>`) so your current branch and working tree are untouched; the review runs
    against the PR's diff vs. its merge base, and the worktree is removed afterward. Requires an
    authenticated `gh`.
  - **Path** — any token containing `/` or a file extension (and not a PR URL) is reviewed
    directly instead of the working diff.
  - none — the local working diff.
- **`--fix`** — switches from report-only to applying the smallest correct change per finding
  (see the output contract). With a **PR scope** it stays report-only by default (the worktree is
  detached/throwaway); ask for PR review comments or a local branch if you want fixes applied.

## How it works

`SKILL.md` is the orchestrator. It parses the request, establishes the scope — a PR (fetched into
an isolated `git worktree`, reviewed against its merge base, then cleaned up), a given path, or the
local working diff (`git status --short` + `git diff HEAD`) — loads `rubrics/output-format.md` plus
the rubric for each selected mode, then runs the tracks in canonical order and emits a consolidated
verdict.

For a **PR scope**, before the tracks run it first reads the PR conversation — the description and
all human review comments — so it honours decisions already made and doesn't re-raise resolved
points, and it checks that the PR title and description accurately describe the diff (flagging a
missing, vague, or stale one).

It then **verifies the description's factual claims against reality** rather than trusting them:

- "146 tests pass" → runs the suite and reports the real number (a claimed 146 that is really 142
  is a finding).
- "see ADR-0027" / references to docs, tickets, sibling files → confirms the artifact actually
  exists and says what the PR claims (a cited-but-never-committed ADR is flagged).
- "fixed X" / "removed Y" → greps the code to confirm the change is actually present.

When the description says the PR **pairs with / depends on / must mirror** another PR — especially
in a different repo (e.g. an index-side change whose normalization must match a query-side rule in
a sibling repo) — it fetches that paired PR and checks the two sides actually agree, since that
correctness contract can't be reviewed from one diff alone.

### Large diffs

When the diff is large (more than ~15 files or ~800 changed lines — big enough that a single
`git diff` can blow past the tool output limit), the skill **fans out**: each track runs in its own
parallel subagent that reads only the files it needs and returns just its findings, and the
orchestrator assembles the consolidated verdict. Small diffs run inline.

### Stacks

The static tracks are **language-agnostic**: each rubric leads with a universal principle and
illustrates it across ecosystems (NestJS/Vue/TS, Java/Spring, Go, Python, Rust, .NET, Rails), so the
review applies to whatever stack the diff is in — the NestJS/Vue examples are just the most fleshed
out. The dynamic `regression-check` track **detects the actual build tool from the repo** —
npm/pnpm/yarn, Maven, Gradle, Go, Python, or .NET — runs that tool's unit set (honouring the pinned
JDK/runtime), and skips integration/E2E steps that need infra it doesn't have rather than faking them.

### The deterministic layer (open-source analyzers)

Tool-backed tracks do a **gather → triage** pass defined in
[`rubrics/tool-registry.md`](rubrics/tool-registry.md). Which tools run is driven by the selected
tracks (so a scoped run doesn't run scanners it won't use):

1. **Gather** (once per review, scoped to the diff): `security` (or an all-tracks run) runs the
   SAST / secrets / dependency tools — Semgrep (SAST/taint), Gitleaks (secrets in the diff *and*
   branch history; GitHub secret-scanning as a PR-scope fallback), Trivy/osv-scanner
   (transitive-dependency CVEs + licenses, only when a manifest changed). `regression` and
   `architecture` gather blast-radius via the built-in LSP `findReferences` (the real call sites a
   signature change breaks) — that fires even without `security`. The analyzers run as a **pinned
   Docker Compose toolchain the skill ships** ([`tools/compose.yml`](tools/compose.yml)) — not from
   the host PATH — so the gather stage is reproducible and versioned. If Docker/Compose isn't
   available the whole deterministic layer **skips gracefully on the record**, never fabricating
   results (LSP/Grep, being built-in session tools, still run).
2. **Triage**: the model takes those structured `path:line` findings *plus the diff*, drops false
   positives (OSS scanners are noisy), dedupes against what the tracks already raised, maps each
   survivor to the skill's severity, and explains why it matters here. Raw scanner output never lands
   in the report; the verdict states which tools ran and which were skipped.

This is the same recipe mature AI reviewers use (run real analyzers → feed findings to the model →
let it triage), built entirely on free, local, no-account tooling.
