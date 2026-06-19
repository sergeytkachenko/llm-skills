# llm-skills

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of personal
skills, published under the `st` namespace.

The repo is both a **marketplace** ([`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json))
and a set of **plugins** under [`plugins/`](plugins/). Each plugin holds one or more skills under
`skills/<name>/SKILL.md`.

## Plugins

| Plugin | Skill | What it does |
| --- | --- | --- |
| [`st`](plugins/st/) | `st:code-review` | Structured multi-track code review (architecture, clean-code, naming, comments, readability, regression, security, regression-check) over your working diff, a path, or a pull request, backed by a deterministic open-source analyzer layer (Semgrep, Gitleaks, Trivy, LSP). Language-agnostic; examples lean NestJS + Vue 3 + TypeScript. |

## Install

Add this repo as a local marketplace, then install the plugin — `git pull` in the repo keeps the
installed plugin up to date:

```sh
git clone https://github.com/sergeytkachenko/llm-skills.git ~/projects/llm-skills
```

Then, inside Claude Code:

```
/plugin marketplace add ~/projects/llm-skills
/plugin install st@st
```

The skill is then invoked as `/st:code-review`. The `st` plugin name keeps it distinct from the
official `code-review@claude-plugins-official` plugin, so both can be installed at once. After a
`git pull`, run `/plugin marketplace update st` to pick up changes.

### Requirements

The skill itself needs nothing beyond Claude Code. Its **deterministic analyzer layer** (the
`security` track, and the SAST/secret/dependency gather on an all-tracks run) additionally needs
**Docker + Compose v2 on Linux or macOS** — it runs a pinned analyzer toolchain
([`plugins/st/skills/code-review/tools/compose.yml`](plugins/st/skills/code-review/tools/compose.yml))
behind a [`preflight`](plugins/st/skills/code-review/tools/preflight.sh) check that validates the OS,
the Docker install, and a running daemon first. Without a working Docker the skill still runs — it
just skips that layer on the record, never fabricating findings.

See each plugin's own README for usage and the [`docs/adr/`](docs/adr/) records for the design
decisions behind the analyzer layer.

## License

MIT
