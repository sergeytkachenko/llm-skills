# 3. Retire the st code-review skill

Date: 2026-09-17

## Status

Accepted. Supersedes [ADR-0001](0001-deterministic-analyzer-layer-for-code-review.md) and
[ADR-0002](0002-docker-compose-toolchain-for-the-analyzer-layer.md).

## Context

`/st:code-review` was the only skill in the `st` plugin. Its owner decided to stop maintaining it:
review now happens through a hook-based multi-model review layer kept in the owner's global Claude
Code configuration, outside this repository. The analyzer layer from ADR-0001 and its Docker Compose
toolchain from ADR-0002 exist only to serve this skill.

## Decision

Delete `plugins/st/` (the skill, its rubrics, output contract and analyzer toolchain), the
`.claude/commands/st-code-review.md` alias and the `st` entry in `.claude-plugin/marketplace.json`.
The repository stays a plugin marketplace with no plugins until a new one is added.

## Consequences

- `/plugin install st@st` no longer works; anyone with the plugin installed should run
  `/plugin uninstall st@st` after the next `/plugin marketplace update st`.
- The skill's history, including the unmerged `feat/code-review-host-fallback` work, remains in git.
- ADR-0001 and ADR-0002 are kept as a record of the retired design.
