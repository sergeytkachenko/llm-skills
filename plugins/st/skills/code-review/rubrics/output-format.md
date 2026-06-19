# Output contract

Applies to every track in this review. Read it before producing any findings.

## Mode of operation
- This is a **review**: report findings only. Do **not** edit, refactor, or create files
  unless the invocation explicitly included `--fix`.
- When `--fix` is present: make the smallest correct change per finding, then summarise what
  you changed. Never bundle unrelated changes.
- Describe each fix as prose (the shape of the change). Include a code snippet only when
  `--fix` is set or the user explicitly asked for code.
- PR scope (detached worktree): `--fix` does **not** edit the worktree — those edits are
  thrown away with it. Stay report-only unless the user said where to apply fixes (PR review
  comments, or a new local branch off the PR head). Never silently edit the detached worktree.
- `--fix` and security findings: some have no "smallest code edit" — a committed secret needs
  **rotation** (out-of-band; the pushed value is already compromised, so deleting it from the diff
  is not a fix), and a dependency CVE needs a version **bump + lockfile regen**. For these, `--fix`
  reports the required action and (for the CVE) may apply the manifest bump, but does **not**
  rewrite git history or fabricate a rotation. Say so rather than no-op silently.

## Severity
Most severe first:
- **Blocker** — must fix before merge (breaks behavior, leaks boundaries, data/regression risk).
- **Major** — should fix (clear violation that will cost the team later).
- **Minor** — worth fixing (smell, small inconsistency).
- **Nit** — optional / stylistic.

## Per-track format
Header: `### <track> — scope: <what was reviewed>`

Then findings, grouped by severity (Blocker → Nit). Each finding is one short block:

    path:line — short title
      why it matters (1 line; frame around maintainability/risk, not personal taste)
      suggestion (prose; minimal diff only when --fix)

If a track finds nothing, say so in one line — do not invent findings to look thorough.
End each track with a one-line verdict: `<n> blockers, <n> majors, <n> minors, <n> nits — <ready | not ready> to merge`.

When a deterministic analyzer corroborates a finding (the `security` track and tool-backed checks —
see `tool-registry.md`), cite it in the finding (`Semgrep <rule-id>`, `Gitleaks`, `Trivy CVE-…`,
`LSP: 3 call sites`) — it marks the finding as tool-confirmed rather than a judgement call. If a
track relied on analyzers, note in its verdict which ran and which were skipped, so a clean result
isn't misread as "scanned clean" when a scanner never executed.

## Consolidated run (all tracks)
When more than one track runs, output one section per track in the order they ran. If two tracks
flag the same `path:line` for the same reason, report it once under the more relevant track and
note the overlap rather than repeating the block. Then a final **Overall verdict**:

    Overall: <n blockers, n majors> — <ready | not ready> to merge
    Top 3 to address first: 1) … 2) … 3) …

## Triage buckets
Every reported finding carries a **bucket** (set during the triage step in `SKILL.md`) in addition
to its severity. The bucket says *what to do with it*; severity says *how bad it is*. Mark it inline,
e.g. `path:line — title  [patch · Major]`.

- **decision-needed** — real, but the right fix needs the user's intent. List these first; never
  auto-fix them under `--fix`. Present the trade-off and let the user choose.
- **patch** — real, with an unambiguous fix. These are what `--fix` applies.
- **defer** — real but pre-existing (not introduced by this change). Report once, don't act on it.
- **dismiss** — noise / false positive / handled elsewhere. **Not listed.** Report only the count
  (e.g. "3 dismissed as noise") so the reader knows they were considered and dropped.

End the consolidated run with one line of bucket counts:
`<D> decision-needed, <P> patch, <W> defer, <R> dismissed`.

## Clean vs incomplete — never conflate them
A clean verdict means *the checks ran and found nothing*. If a layer did **not** run — a scanner was
skipped (Docker down, service failed), a track's subagent failed or returned empty, or a tool was
unavailable — you may not call the result "clean". Say **"review incomplete"** instead, name what
didn't run, and present whatever the surviving layers found. A reader must never mistake "we couldn't
look" for "we looked and it's fine." (This reinforces the per-track "which ran / which skipped" note
above — apply it to the overall verdict too.)

## Tone
Be direct and concrete. Point to the exact line. No praise padding, no restating the code back.
Prefer "rename X to Y because…" over "consider possibly improving naming".
