# 2. Docker Compose toolchain for the deterministic analyzer layer

Date: 2026-06-19

## Status

Accepted. Supersedes the execution-strategy part of [ADR-0001](0001-deterministic-analyzer-layer-for-code-review.md)
(the "ephemeral-first → graceful-skip" decision). The tool *selection* and the gather→triage
contract from ADR-0001 stand unchanged.

## Context

ADR-0001 introduced the deterministic analyzer layer (Semgrep, Gitleaks, Trivy/osv-scanner) and ran
each tool **ephemeral-first**: use it if on `PATH`, else `uvx`/`npx`/`docker run`, else skip. That
worked but had real downsides:

- **Non-reproducible.** Whichever Semgrep/Trivy version happened to be on `PATH` (or whatever `uvx`
  resolved that day) drove the findings — two machines could disagree. Analyzer findings are
  version-sensitive (rule packs, vuln DBs), so "it depends what's installed" is a correctness
  problem, not just a convenience one.
- **Four invocation paths** (PATH / uvx / npx / docker run) per tool, each with its own quirks,
  multiplied the prose and the failure modes the skill had to reason about.
- **No version pinning**, so a silent upstream change could move findings under the user's feet.

The skill is distributed as a plugin, so it can ship its own files. That makes a self-contained,
pinned toolchain feasible rather than depending on the host environment.

## Decision

Run the deterministic analyzers **only** through a Docker Compose file the skill ships
(`plugins/st/skills/code-review/tools/compose.yml`):

- One service per analyzer (`semgrep`, `gitleaks`, `trivy`, `osv-scanner`), each pinned to a
  specific image tag. Bumping a tag is a deliberate, reviewable change.
- Invocation is uniform: `REVIEW_DIR=<path> docker compose -f <compose> run --rm <service> <args>`.
  The code under review mounts read-only at `/src`; reports are written to a separate writable
  mount `/out` (a host `mktemp -d` outside the reviewed tree), never into `/src`. See the
  Implementation notes below for the exact mount layout.
- **Compose is the only mechanism.** No host-PATH use, no `uvx`/`npx`/`docker run` fallback. If
  Docker/Compose is unavailable, the entire deterministic layer skips on the record and the tracks
  reason without tool corroboration.
- The built-in `LSP` (blast radius) and `Grep` are the explicit exceptions — they are session tools,
  not toolchain analyzers, so they don't run in a container.

## Consequences

- **Positive:** reproducible, versioned findings — the same image tags produce the same results
  anywhere Docker runs. One invocation path instead of four. Vuln DBs cache in named volumes, so the
  first-run download is paid once. The skill is self-contained: it brings its own tools.
- **Negative:** Docker is now a hard prerequisite for the deterministic layer. On a host without
  Docker (some CI sandboxes, locked-down machines) the whole layer skips — previously a host-PATH
  binary might still have run. This is an accepted trade: reproducibility over best-effort coverage,
  with the skip made explicit in the verdict so it is never mistaken for "scanned clean."
- **Negative:** image tags need periodic maintenance (security rule packs and vuln DBs go stale);
  bumping them is now an explicit chore rather than implicit drift — which is the point, but it is a
  chore.
- **Follow-up:** if a no-Docker execution path becomes important, revisit with a separate fallback
  ADR rather than re-adding the ad-hoc ephemeral runners this decision removed.

## Implementation notes

These refine *how* the decision above is realized; they don't change it. They record details that
settled during review, so the ADR matches the shipped `compose.yml` / `tool-registry.md` /
`preflight.sh`:

- **Mounts.** The code under review is mounted **read-only** at `/src`; reports are written to a
  **separate writable** mount `/out` (a host `mktemp -d` outside the reviewed tree), never into
  `/src`. This avoids both a read-only-filesystem write error and leaking a `.review/` dir into the
  user's checkout.
- **Linked worktrees.** For a PR reviewed in a `git worktree`, `/src/.git` is a pointer file and the
  object store lives in the parent repo. Gitleaks gets the real store mounted at `/gitcommon`
  (`git rev-parse --path-format=absolute --git-common-dir`) and reads it via `GIT_DIR=/gitcommon`.
- **Preflight + scope.** A shipped `tools/preflight.sh` gates the layer to **Linux/macOS only** and
  validates the Docker CLI, **Compose v2** (not legacy v1), and a **running, reachable daemon**
  before any gather — each failure exits with a distinct code and an on-the-record skip reason.
- **Skip granularity.** Two levels: a failed preflight skips the **whole** layer; after preflight, a
  single service that can't pull/fetch/run is skipped **per-tool** so one blocked scanner neither
  passes as "scanned clean" nor kills the others.
- **Caching.** Each network-dependent service (Semgrep rule packs, Trivy/osv vuln DBs) has its own
  named cache volume, so the first-run fetch is paid once; only Gitleaks is offline from the start.
