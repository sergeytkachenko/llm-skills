---
name: code-review
description: Use this skill when the user asks to "code review", "/code-review", "review my changes", "review this diff/PR", or "code review <path>". Reviews the working diff (or a given path) across seven tracks — architecture, clean-code, naming, comments, readability, regression (static risk), and regression-check (runs the test/lint/typecheck suite). Accepts mode(s) to scope which tracks run, an optional path, and `--fix` to apply minimal fixes. Tuned for NestJS + Vue 3 + TypeScript.
version: 0.1.0
---

# Code review

Run the ST code review over the current changes (or a given path), one or more tracks at a time.

## 1. Parse the request

Treat the text the user passed when invoking this skill as ARGS.
- Strip a leading `--mode` / `--mode=`; treat the remainder as a comma-separated list of MODES.
- A token containing `/` or a file extension is the SCOPE (a path), not a mode.
- A `--fix` token enables **fix mode** (see the output contract). Strip it from the mode list.
- Valid modes: `architecture`, `clean-code`, `naming`, `comments`, `readability`, `regression`,
  `regression-check`.
- No modes given → run ALL of them, in the order listed above.
- No path given → SCOPE = the working changes (step 2). A path given → SCOPE = that path (read it).

## 2. Establish the scope under review

If a path SCOPE was given, read that path and review it. Otherwise, gather the working changes
yourself by running:

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
