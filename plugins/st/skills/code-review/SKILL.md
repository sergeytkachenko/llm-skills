---
name: code-review
description: Use this skill when the user asks to "code review", "/code-review", "review my changes", "review this diff/PR", "code review <path>", or "code review <pull-request-url>". Reviews the working diff, a given path, or a pull request (checked out into an isolated git worktree) across eight tracks — architecture, clean-code, naming, comments, readability, regression (static risk), security (taint/secrets/SCA backed by OSS analyzers), and regression-check (runs the test/lint/typecheck suite). Runs deterministic open-source analyzers (Semgrep, Gitleaks, Trivy, LSP find-references) and feeds their findings into the LLM to triage — catching what reading a diff misses. For a PR it also verifies the description's factual claims against reality (real test counts, cited ADRs/docs exist, "fixed X" is actually in the code) and follows paired/dependency PRs when a correctness contract spans repos. Fans out to parallel subagents for large diffs. Accepts mode(s) to scope which tracks run, an optional path, an optional PR URL, and `--fix` to apply minimal fixes. Checks are language-agnostic (examples lean toward NestJS + Vue 3 + TypeScript, but the rubrics apply to Java/Spring, Go, Python, Rust, .NET, etc.); the dynamic track detects the actual stack (Maven/Java, Gradle, Go, Python, .NET).
version: 0.4.0
---

# Code review

Run the ST code review over the current changes (or a given path), one or more tracks at a time.

## 1. Parse the request

Treat the text the user passed when invoking this skill as ARGS. Classify each token:
- A **PR URL** (`https://github.com/<owner>/<repo>/pull/<n>`) or a bare `#<n>` / `<owner>/<repo>#<n>`
  PR reference is the SCOPE. This takes precedence over a path. → review the PR (step 2a).
- A token containing `/` or a file extension (and that is *not* a PR URL) is a **path** SCOPE. →
  review that path (step 2b).
- A `--fix` token enables **fix mode** (see the output contract). Strip it from the mode list.
- A leading `--mode` / `--mode=` is stripped; the remaining non-scope, non-flag tokens form a
  comma-separated list of MODES.
- Valid modes: `architecture`, `clean-code`, `naming`, `comments`, `readability`, `regression`,
  `security`, `regression-check`.
- No modes given → run ALL of them, in the order listed above.
- No scope given → SCOPE = the local working changes (step 2c).

Pick exactly one scope. Precedence when more than one is present: PR URL > path > working changes.

## 2. Establish the scope under review

Follow the branch that matches the SCOPE from step 1.

### 2a. PR URL → review in an isolated git worktree

When the SCOPE is a pull request, **never** check the PR out onto the current branch or into the
working tree — review it in a throwaway worktree so the user's checkout is untouched.

1. Parse `<owner>/<repo>` and `<n>` from the URL/reference. Confirm `gh` is authenticated
   (`gh auth status`); if not, tell the user to run `gh auth login` and stop.
2. Make sure you're inside the right git repo. If the current repo's `origin` doesn't match
   `<owner>/<repo>`, clone it to a temp dir first (`gh repo clone <owner>/<repo> <tmp>`), and run
   the rest there. If it does match, use the current repo.
3. Fetch the PR head and create a detached worktree for it (avoids touching the current branch):

   ```
   git fetch origin pull/<n>/head
   WT="$(git rev-parse --show-toplevel)/.worktrees/pr-<n>"
   git worktree add --detach "$WT" FETCH_HEAD
   ```

   (If `git fetch origin pull/<n>/head` fails — e.g. a fork without that ref — fall back to
   `gh pr checkout <n>` inside a fresh clone, or `git worktree add --detach "$WT" "$(gh pr view <n> --json headRefOid -q .headRefOid)"`.)
4. Determine the PR's merge base and gather its diff from **inside the worktree**:

   ```
   cd "$WT"
   BASE="$(gh pr view <n> --repo <owner>/<repo> --json baseRefName -q .baseRefName)"
   git fetch origin "$BASE"
   git diff "origin/$BASE...HEAD"          # the PR's changes only
   git diff --stat "origin/$BASE...HEAD"
   ```

   The SCOPE for every track is this PR diff (read the touched files in the worktree for
   surrounding context as needed). Steps 5–6 gather the PR's conversation and metadata.
5. **Read the PR conversation before reviewing the code.** Pull every human comment — the PR
   description, review threads, and inline comments
   (`gh pr view <n> --repo <owner>/<repo> --comments`, `gh api repos/<owner>/<repo>/pulls/<n>/comments`).
   They carry context the diff cannot: the author's intent, constraints already agreed, decisions
   made in discussion, and known follow-ups. Honour them — do not re-raise a point a human already
   resolved, and treat an open reviewer concern as a finding to confirm, not rediscover.
   - **Read the CI status, don't guess it.** Pull the PR's check runs (`gh pr checks <n>`, or the
     GitHub MCP `pull_request_read` `get_check_runs`/`get_status`). If the suite is already red,
     report *that* ("CI failing on `<job>`") instead of speculating about whether tests pass — and
     reconcile it against any "all green" claim in the description (per step 7).
6. **Check the PR title and description match the change.** Before the tracks run, verify the
   title is a clear, accurate summary of the diff and the description explains *why* and covers
   what actually changed. Flag (as a Major) a title/description that is missing, vague, stale
   (describes something the diff no longer does), or omits a user-visible/breaking change present
   in the code. Suggest a corrected title/description. With `--fix` and a PR scope, propose the
   edit for the user to apply — do not silently rewrite the PR.
7. **Verify the description's factual claims — don't trust them.** A PR description asserts
   things a reviewer must confirm against reality, not take on faith. For every checkable claim,
   *check it* and flag any that is false or unverifiable (severity per how load-bearing it is):
   - **"N tests pass" / "all green"** → actually run the suite (the `regression-check` track does
     this) and report the real number. A claim of 146 that is really 142 is a Major: it means the
     description is stale or the author never ran what they cite.
   - **References to ADRs, docs, tickets, or sibling files** (`ADR-0027`, `docs/…`, `CHANGELOG.md`)
     → confirm the referenced artifact actually exists in the diff/repo and says what the PR claims.
     A cited ADR that was never committed is a Major (dangling rationale).
   - **"Fixed X" / "removed Y" / "now does Z"** → grep the code to confirm the fix/removal is
     actually present, not just described. If a claimed fix isn't in the code, say so.
   - **Cross-repo / paired-PR contracts** (see step 8 below) → verify, don't assume.
   Be skeptical by default: the description is the author's intent, the code is the truth, and your
   job is to find where they diverge.
8. **Follow dependency / paired PRs when a contract spans repos.** If the description says this PR
   "pairs with", "depends on", or "must mirror" another PR — especially in a *different* repo
   (e.g. an index-side change whose normalization must match a query-side `query_norm` in a sibling
   repo) — the correctness contract lives across both and cannot be reviewed from this diff alone.
   Fetch the paired PR (`gh pr diff <n> --repo <owner>/<repo>`, or clone + `gh pr checkout`) and
   confirm the two sides actually agree (matching field names, identical normalization rules, same
   ordering, compatible types). A silent divergence between the two halves is a Blocker — it ships
   green on both sides and breaks only at runtime. If the paired PR is inaccessible (private/auth),
   say so explicitly and flag the contract as unverified rather than assuming it holds.
9. **Cleanup is mandatory.** After the review finishes (or if you abort), remove the worktree:
   `git worktree remove --force "$WT"` (and `rm -rf <tmp clone>` if you cloned). Do this even on
   failure. Tell the user the worktree path while it exists, in case they want to inspect it.
10. `--fix` with a PR scope: by default still **report only** — a worktree is detached and throwaway,
   so fixes there would be lost. If the user explicitly wants fixes applied, confirm where: post
   them as PR review comments (`gh pr comment` / inline review), or apply on a new local branch
   tracking the PR head — do not silently edit the detached worktree.

### 2b. Path → read it

Read the given path and review it directly. That file/tree is the SCOPE.

### 2c. Local working changes (default)

Gather the working changes yourself by running:

```
git status --short
git diff HEAD
```

Use that status + diff as the SCOPE for every selected track.

## 3. Load the rules

These files live alongside this `SKILL.md`, in `rubrics/`. Read them with the Read tool using
paths relative to the skill directory.

- Read `rubrics/output-format.md` first — it defines severity, the finding format, and the
  report-only / `--fix` rule. Follow it for every track.
- For EACH selected mode, read `rubrics/<mode>.md` and apply it to SCOPE.
- Do NOT apply rubrics for modes that were not selected.
- If `security`, `regression`, or `architecture` is selected (or all tracks run), also read
  `rubrics/tool-registry.md` — it defines the open-source analyzer layer and the gather → triage
  contract those tracks depend on (`security` for SAST/secret/SCA; `regression` and `architecture`
  for LSP find-references / blast radius).

## 4. Run

Run the selected track(s) in the canonical order (architecture, clean-code, naming, comments,
readability, regression, security, regression-check). The `regression-check` track executes the
project's test/lint/typecheck scripts, so a bare invocation with no modes (all tracks) will run the
suite — pass explicit modes to skip it. If more than one track ran, end with a single consolidated
verdict per the output contract.

### Gather the deterministic findings once

Before reasoning, run the **gather** stage defined in `rubrics/tool-registry.md` — **once** for the
whole review. The analyzers run as a **pinned Docker Compose toolchain the skill ships**
(`tools/compose.yml`) — not from the host PATH; that file is the source of truth for *how* each tool
runs (the `docker compose run` invocation, the writable `/out` mount, report parsing, per-service
skip, cleanup), so don't restate the mechanics here. Preflight `docker compose version` once; if
Docker is unavailable, skip the whole deterministic layer **on the record** — but if Docker is up
and one *service* fails (image pull, blocked fetch, timeout), skip just that tool on the record and
keep the rest (the tracks still reason, just without that tool's corroboration). What this step
decides is *which* tools to gather, driven by the **selected tracks** — gather only what a selected
track will consume, so a scoped run isn't forced to run scanners it won't use:

- `security` selected (or all tracks) → run the SAST / secrets / dependency services (Semgrep,
  Gitleaks — or the PR-scope `run_secret_scanning` fallback when Docker is unavailable —
  Trivy/osv-scanner when a manifest changed).
- `regression` **or** `architecture` selected (or all tracks) → gather blast-radius via the built-in
  `LSP` `findReferences` on changed symbols. This fires even when `security` is *not* selected — the
  LSP gather is owned by these tracks, not by `security`.
- Carry the findings as a structured `tool | path:line | rule | severity` list into those tracks,
  which **triage** them (drop false positives, dedupe, map to this skill's severity, explain). Raw
  analyzer output never goes in the report.
- State which tools ran and which were skipped, so a clean verdict is never mistaken for "scanned
  and clean" when a scanner never executed (per `output-format.md`).

If **no** gather-consuming track is selected (e.g. `/code-review naming`), skip this step entirely.

### Large diffs — fan out instead of choking

A big PR's diff can be too large to hold in one context (a single `gh`/`git diff` can exceed the
tool output limit; you saw this when the diff was 3k+ lines / 150k+ chars). Don't truncate the diff
and review a fraction of it silently. When the diff is large (rough trigger: `git diff --stat` shows
**more than ~15 files or ~800 changed lines**), delegate each track to its own subagent (the `Agent`
tool) and run them in parallel:

- **Run the gather stage in the orchestrator first**, before spawning subagents — once — per the
  section above. The deterministic findings must not evaporate just because the diff is large; the
  large-diff case is exactly when they matter most.
- Spawn one subagent per selected track. Give each: the SCOPE (worktree path or the base/head refs so
  it can run `git diff origin/<base>...HEAD` itself), the matching rubric, the output contract, **and
  the gathered findings relevant to that track** (the `tool | path:line | rule | severity` list — and
  for `regression`/`architecture`, the LSP call-site list, since `LSP` is a session-bound built-in a
  subagent cannot re-run). The subagent triages what it's handed; it does not re-scan.
- Tell each to read only the files its track needs — not to echo the diff back.
- Each subagent returns **only its findings** in the per-track format, never file dumps. You collect
  them and emit the consolidated verdict.
- This keeps the orchestrator's context clean and lets `regression-check` (which runs `mvn`/`npm`,
  potentially minutes) run alongside the static tracks instead of blocking them.

For a small diff, run the tracks inline as before — fan-out overhead isn't worth it.
