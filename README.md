# llm-skills

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of personal
skills, published under the `st` namespace.

The repo is both a **marketplace** ([`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json))
and a set of **plugins** under [`plugins/`](plugins/). Each plugin holds one or more skills under
`skills/<name>/SKILL.md`.

## Plugins

| Plugin | Skill | What it does |
| --- | --- | --- |
| [`code-review`](plugins/code-review/) | `st:code-review` | Structured multi-track code review (architecture, clean-code, naming, comments, readability, regression, security, regression-check) over your working diff, a path, or a pull request, backed by a deterministic open-source analyzer layer (Semgrep, Gitleaks, Trivy, LSP). Language-agnostic; examples lean NestJS + Vue 3 + TypeScript. |

## Install

Add this repo as a local marketplace, then install the plugin — `git pull` in the repo keeps the
installed plugin up to date:

```sh
git clone https://github.com/sergeytkachenko/llm-skills.git ~/projects/llm-skills
```

Then, inside Claude Code:

```
/plugin marketplace add ~/projects/llm-skills
/plugin install code-review@st
```

The skill is then invoked as `/st:code-review`. The `st` namespace keeps it distinct from the
official `code-review@claude-plugins-official` plugin, so both can be installed at once.

See each plugin's own README for usage.

## License

MIT
