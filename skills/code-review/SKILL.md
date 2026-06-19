---
name: code-review
description: Use this skill when the user asks to "code review", "/code-review", "review my changes", "review this diff/PR", "code review <path>", or "code review <pull-request-url>". Reviews the working diff, a given path, or a pull request (checked out into an isolated git worktree) across seven tracks — architecture, clean-code, naming, comments, readability, regression (static risk), and regression-check (runs the test/lint/typecheck suite). Accepts mode(s) to scope which tracks run, an optional path, an optional PR URL, and `--fix` to apply minimal fixes. Tuned for NestJS + Vue 3 + TypeScript.
version: 0.1.0
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
  `regression-check`.
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
6. **Check the PR title and description match the change.** Before the tracks run, verify the
   title is a clear, accurate summary of the diff and the description explains *why* and covers
   what actually changed. Flag (as a Major) a title/description that is missing, vague, stale
   (describes something the diff no longer does), or omits a user-visible/breaking change present
   in the code. Suggest a corrected title/description. With `--fix` and a PR scope, propose the
   edit for the user to apply — do not silently rewrite the PR.
7. **Cleanup is mandatory.** After the review finishes (or if you abort), remove the worktree:
   `git worktree remove --force "$WT"` (and `rm -rf <tmp clone>` if you cloned). Do this even on
   failure. Tell the user the worktree path while it exists, in case they want to inspect it.
8. `--fix` with a PR scope: by default still **report only** — a worktree is detached and throwaway,
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

## 4. Run

Run the selected track(s) in the canonical order (architecture, clean-code, naming, comments,
readability, regression, regression-check). The `regression-check` track executes the project's
test/lint/typecheck scripts, so a bare invocation with no modes (all tracks) will run the suite —
pass explicit modes to skip it. If more than one track ran, end with a single consolidated verdict
per the output contract.
