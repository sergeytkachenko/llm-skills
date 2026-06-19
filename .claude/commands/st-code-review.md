---
description: Structured code review across eight tracks (architecture, clean-code, naming, comments, readability, regression, security, regression-check) with a deterministic OSS analyzer layer. Alias for the st:code-review skill.
argument-hint: "[mode(s)] [path] [PR URL] [--fix]"
---

Run the ST code review by invoking the bundled skill. Treat `$ARGUMENTS` as the
skill's ARGS verbatim (mode(s), an optional path, an optional PR URL, and `--fix`).

Invoke the `st:code-review` skill with `$ARGUMENTS` and follow its instructions
exactly — parse the request, select tracks, run the gather/analyzer stage, and
emit the consolidated verdict per the skill's output contract. Do not re-implement
the review logic here; delegate fully to the skill.
