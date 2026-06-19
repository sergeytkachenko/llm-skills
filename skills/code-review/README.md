# code-review skill

A Claude Code [Skill](https://docs.claude.com/en/docs/claude-code/skills) that runs a structured
"ST code review" over your working diff (or a given path), across seven independent tracks. Tuned
for **NestJS + Vue 3 + TypeScript**.

## Tracks

| Mode | Lens |
| --- | --- |
| `architecture` | Clean Architecture — boundaries, dependency direction, layering, SOLID, contracts at the edges. |
| `clean-code` | Function/method-level — shape, complexity, DRY, magic values, error handling, TS discipline, async correctness. |
| `naming` | Intention-revealing, honest, domain-language, grammar, casing, cross-codebase consistency. |
| `comments` | Why-not-what, self-explanatory code first, dead weight, truthfulness, TODO hygiene, public-API docs. |
| `readability` | Zoom-out integrative pass — cognitive load, consistency, discoverability, coherent narrative. |
| `regression` | Static risk analysis — changed contracts, backward compat, edge cases, side effects, blast radius. |
| `regression-check` | Dynamic — runs the project's own typecheck / lint / test / e2e scripts and reports failures. |

The output contract (severity levels, finding format, the report-only vs `--fix` rule) lives in
[`rubrics/output-format.md`](rubrics/output-format.md) and applies to every track.

## Install

Skills load from `~/.claude/skills/<name>/`. Symlink this skill in so `git pull` in the
[`llm-skills`](../../README.md) repo keeps the live skill up to date:

```sh
git clone https://github.com/sergeytkachenko/llm-skills.git ~/projects/llm-skills
ln -s ~/projects/llm-skills/skills/code-review ~/.claude/skills/code-review
```

(Or copy the directory into `~/.claude/skills/code-review` instead of symlinking.)

## Usage

Invoke `/code-review` with optional mode(s), an optional scope (path **or** PR URL), and an
optional `--fix`:

```
/code-review                                         # all tracks over the working diff (runs the test suite)
/code-review naming                                  # just the naming track over the working diff
/code-review naming,comments                         # two tracks
/code-review architecture src/auth                   # one track, scoped to a path
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
