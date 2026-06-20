---
name: code-review
description: Use this skill when the user asks to "code review", "/code-review", "review my changes", "review this diff/PR", "code review <path>", or "code review <pull-request-url>". Reviews the working diff, a path, or a PR (in an isolated git worktree) across eight tracks — architecture, clean-code, naming, comments, readability, regression, security, and regression-check (runs the test/lint/typecheck suite). Backs the LLM with deterministic OSS analyzers (Semgrep, Gitleaks, Trivy, LSP find-references) — via a pinned Docker toolchain, falling back to host binaries when Docker is absent — and triages their findings. For a PR it verifies the description's factual claims against the code and follows paired/cross-repo PRs. Adds a context-free "Blind Hunter" adversarial pass, then dedupes across layers and buckets each finding into decision-needed / patch / defer / dismiss. Resolves the target by cascade, fans out to parallel subagents for large diffs, and accepts mode(s), an optional path, an optional PR URL, and `--fix`. Language-agnostic (examples lean NestJS + Vue 3 + TS; the dynamic track detects the actual stack — Maven/Gradle/Go/Python/.NET).
version: 0.6.0
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

### Resolve the SCOPE by cascade — stop at the first tier that identifies it

Pick exactly one scope. The conversation before this skill fired IS context, not a blank slate.
Walk the tiers in order and **stop as soon as a tier identifies the target** — do not ask a question
a tier above already answered, and do not keep probing once you have a scope.

- **Tier 1 — explicit argument.** A token in ARGS names the scope:
  - PR URL / `#<n>` / `<owner>/<repo>#<n>` → PR scope (step 2a). Takes precedence over everything.
  - A token with `/` or a file extension (not a PR URL) → path scope (step 2b).
  - Diff-mode keywords narrow a working-tree scope: "staged" → `git diff --cached`; "uncommitted" /
    "working tree" / "all changes" → `git diff HEAD`; "vs <branch>" / "against <branch>" / "branch
    diff" → diff against that base. Prefer the most specific match.
- **Tier 2 — recent conversation.** If ARGS named no scope, do the last few messages reveal what to
  review (a PR link, a branch, a path, a described change)? Apply the same keyword scan as Tier 1.
- **Tier 3 — current git state.** If still unresolved and inside a repo: if HEAD is on a non-default
  branch, confirm with the user ("review `<branch>`'s changes vs `main`?") before treating it as a
  branch diff. Otherwise fall through.
- **Tier 4 — default.** No scope anywhere → SCOPE = the local working changes (step 2c).

Precedence when more than one explicit scope is present: PR URL > path > working changes.

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

Gather the working changes yourself. Always run `git status --short` for orientation, then run the
diff command the cascade resolved in step 1 — `git diff HEAD` for the default/"uncommitted" case,
`git diff --cached` when a "staged" keyword narrowed the scope, or `git diff <base>...HEAD` when a
"vs <branch>" keyword named a base. With no narrowing keyword, default to:

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
suite — pass explicit modes to skip it.

The sub-steps run in this order: **gather** the deterministic findings once → run the selected
**tracks** together with the **Blind Hunter** pass (inline they run one after another; on a large
diff the Blind Hunter is just one more parallel subagent alongside the track agents) → **triage**
(dedupe across layers + bucket) → emit the consolidated verdict per the output contract.

### Gather the deterministic findings once

Before reasoning, run the **gather** stage defined in `rubrics/tool-registry.md` — **once** for the
whole review. The analyzers run as a **pinned Docker Compose toolchain the skill ships**
(`tools/compose.yml`) by default; that file is the source of truth for *how* each tool
runs (the `docker compose run` invocation, the writable `/out` mount, report parsing, per-service
skip, cleanup), so don't restate the mechanics here. Run the skill's `preflight.sh` once; if it
returns non-zero (Docker unavailable), take the **host-binary fallback** the registry defines — run
whatever tools the preflight's `fallback:` line reports present, directly from the host — and only
fully skip the deterministic layer **on the record** when `fallback: none`. If Docker is up
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

If **no** gather-consuming track is selected (e.g. `/st:code-review naming`), skip this step entirely.

### Blind Hunter — one adversarial pass with no context

The tracks above review *with* context: the PR description, the author's stated intent, the
surrounding code. That context is necessary, but it also lets you rationalize a bug ("the description
says this is intentional", "the author clearly meant…"). To counter that bias, run **one** extra
reviewer that sees **only the diff** — no PR description, no spec, no conversation, no project access
beyond the diff text itself. Stripped of intent, it judges the code purely on what is written.

- Spawn it as a separate subagent (the `Agent` tool, `Explore` or `general-purpose`). Hand it
  **only** the SCOPE diff (from step 2) and this instruction; do **not** pass the PR description, the
  comments from step 5, or any rubric. Its job: find correctness bugs, broken edge cases, unsafe
  assumptions, and contradictions *visible in the diff alone* — report each as `path:line — title`
  + why.
- Run it for every review that has a diff (PR or working-tree scope). Skip it only for a pure
  path-scope read with no diff, or a single-track style run (`/st:code-review naming`) where an
  adversarial correctness pass adds nothing.
- Its findings are **inputs to triage** (next section), not a separate report section — they get
  deduped against the tracks and bucketed like any other finding, tagged `source: blind`.

### Triage — dedupe across layers, then bucket

You now have findings from the layers that actually ran — up to three sources: the selected tracks,
the deterministic analyzers (gather), and the Blind Hunter. A scoped run may have only one (e.g.
`/st:code-review naming` skips both gather and the Blind Hunter). Before presenting anything,
consolidate whatever ran.

1. **Deduplicate across sources.** When two findings describe the same issue at the same
   `path:line`, merge into one: keep the most specific as the base (a tool-confirmed or
   line-precise finding beats prose), fold any unique detail/reasoning from the others into it, and
   tag the merged `source` (e.g. `blind+regression`, `security+Semgrep`). Never list the same issue
   twice.
2. **Bucket each surviving finding into exactly one** category — this is orthogonal to severity (a
   finding still carries its Blocker/Major/Minor/Nit), and drives what happens next:
   - **decision-needed** — a real issue whose correct fix is ambiguous without the user's intent
     (a design trade-off, a spec gap). Cannot be auto-fixed; needs a human call.
   - **patch** — a real issue with an unambiguous fix. Safe to apply under `--fix`.
   - **defer** — real but pre-existing, not introduced by this change. Note it, don't act on it now.
   - **dismiss** — noise, false positive, or already handled elsewhere. **Dropped** from the report;
     keep only a count.
3. Carry these buckets into the output per `rubrics/output-format.md` (which defines how they
   surface and the clean-vs-incomplete rule).

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
- Spawn the **Blind Hunter** as one more parallel subagent (diff only, no context) alongside the
  track agents — it costs nothing extra to run it concurrently and it matters most on large diffs.
- The orchestrator does the cross-layer **dedupe + bucket** step itself after collecting every
  subagent's findings — a subagent only sees its own layer and cannot dedupe against the others.
- Tell each to read only the files its track needs — not to echo the diff back.
- Each subagent returns **only its findings** in the per-track format, never file dumps. You collect
  them and emit the consolidated verdict.
- This keeps the orchestrator's context clean and lets `regression-check` (which runs `mvn`/`npm`,
  potentially minutes) run alongside the static tracks instead of blocking them.

For a small diff, run the tracks inline as before — fan-out overhead isn't worth it.
