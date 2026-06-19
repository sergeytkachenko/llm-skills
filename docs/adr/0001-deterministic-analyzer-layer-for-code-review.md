# 1. Deterministic open-source analyzer layer for the code-review skill

Date: 2026-06-19

## Status

Accepted

## Context

The `code-review` skill (`plugins/code-review/skills/code-review/`) originally reviewed a diff by LLM reasoning alone —
the model read the diff and the surrounding files and produced findings against a set of rubric
tracks. That "LLM-over-diff" approach has a structural ceiling: a model reading a diff cannot
reliably see facts that live outside the hunk or outside its training. Specifically it misses
cross-file taint (a source in one file reaching a sink in another), whether a leaked credential is
actually live, which transitive dependency carries a known CVE (there is no advisory database in the
model's head), and who actually calls a changed symbol (blast radius).

Mature AI code-review products (CodeRabbit, Codacy, Bito) converge on the same recipe: run real
deterministic analyzers, feed their structured `file:line` findings to the model, and let the model
triage (drop false positives, dedupe, explain). We wanted that capability but constrained to a
**free, local, no-account, open-source** toolchain so the skill stays runnable in a sandbox with no
paid SaaS dependency.

Key choices a future contributor would reasonably want to re-litigate, hence this record:

- **Which tools.** Semgrep (CE) for SAST, Gitleaks for secrets, Trivy/osv-scanner for SCA, the
  built-in LSP for blast radius, reviewdog as optional diff-scoping glue, and the project's native
  type-aware linter. Notable rejections: **CodeQL** (CLI licence forbids private/CI use without paid
  GHAS), **Snyk** / **SonarCloud taint** (account + cloud upload; deepest taint paywalled).
- **Where the work lives.** A new `security` track (8th) plus a shared `rubrics/tool-registry.md`
  defining the analyzer layer, rather than embedding tool calls ad-hoc in each rubric.
- **Execution strategy.** Ephemeral-first (`uvx`/`npx`/`docker run`) then graceful-skip-on-record,
  so no prior install is required and the skill never fabricates results when a tool is absent.
- **Run-once contract.** Gather runs once per review in the orchestrator (scoped to the diff),
  driven by which tracks are selected; findings are passed down to the consuming tracks (and to
  fan-out subagents) for triage. The native linter is owned solely by `regression-check` to avoid a
  double run.

## Decision

Add a deterministic analyzer layer to the code-review skill:

1. Introduce `rubrics/tool-registry.md` as the single source of truth for the open-source analyzer
   set, their invocation (ephemeral-first → graceful-skip), diff-scoping, and the two-stage
   **gather → triage** contract.
2. Add a first-class `security` track (`rubrics/security.md`) that consumes the SAST/secrets/SCA
   gather and reasons about exploitability over the diff.
3. Wire blast-radius gather (built-in LSP `findReferences`) into the `regression` and `architecture`
   tracks; these gather independently of `security`.
4. Keep the layer OSS-only and no-account; tools are optional and degrade gracefully.

## Consequences

- **Positive:** the review now catches what diff-reading misses (cross-file taint, live secrets,
  CVE'd deps, real call sites), with tool-corroborated findings cited by rule id. Coverage is
  configurable per selected track, and the layer adds no paid dependency.
- **Positive:** a single registry keeps tool choices and the gather contract in one place.
- **Negative / cost:** the gather contract spans the orchestrator and several rubric files, so its
  invariants (run-once, who owns the native linter, when gather fires for a scoped run) must be kept
  in sync — a class of drift this skill did not previously have. Ephemeral runs need network on
  first use; an air-gapped run loses the tools and says so.
- **Negative:** `security` is not a pure read-diff track — it runs external processes and has
  bespoke `--fix` semantics (rotation/CVE-bump aren't "smallest code edits"). A future cross-cutting
  track (perf, SBOM) will likely need similar wiring; if a third such track appears, generalize the
  "a track may declare a gather dependency" mechanism rather than hand-wiring a fourth.
- **Follow-up:** revisit the tool set if CodeQL's licensing changes or a strong OSS cross-file taint
  engine emerges; supersede this ADR rather than editing it.
