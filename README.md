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

Skills load from `~/.claude/skills/<name>/`. Symlink this repo in so `git pull` keeps the live
skill up to date:

```sh
git clone https://github.com/sergeytkachenko/code-review-skill.git ~/projects/code-review-skill
ln -s ~/projects/code-review-skill ~/.claude/skills/code-review
```

(Or copy the directory into `~/.claude/skills/code-review` instead of symlinking.)

## Usage

Invoke `/code-review` with optional mode(s), an optional path, and an optional `--fix`:

```
/code-review                       # all tracks over the working diff (runs the test suite)
/code-review naming                # just the naming track over the working diff
/code-review naming,comments       # two tracks
/code-review architecture src/auth # one track, scoped to a path
/code-review clean-code --fix      # apply minimal fixes for each finding
```

Argument rules:

- **Modes** — comma-separated; omit to run all tracks in canonical order. A leading `--mode` /
  `--mode=` is stripped.
- **Path** — any token containing `/` or a file extension is treated as the scope to review
  instead of the working diff.
- **`--fix`** — switches from report-only to applying the smallest correct change per finding
  (see the output contract).

## How it works

`SKILL.md` is the orchestrator. It parses the request, establishes the scope (running
`git status --short` + `git diff HEAD`, or reading the given path), loads
`rubrics/output-format.md` plus the rubric for each selected mode, then runs the tracks in
canonical order and emits a consolidated verdict.

## License

MIT
