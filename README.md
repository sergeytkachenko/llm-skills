# llm-skills

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of personal
skills, published under the `st` namespace.

The repo is both a **marketplace** ([`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json))
and a set of **plugins** under `plugins/`. Each plugin holds one or more skills under
`skills/<name>/SKILL.md`.

## Plugins

None at the moment. The `st` plugin and its `st:code-review` skill were retired — see
[ADR-0003](docs/adr/0003-retire-the-st-code-review-skill.md). If you installed it, run
`/plugin marketplace update st` and then `/plugin uninstall st@st`.

## Install

```sh
git clone https://github.com/sergeytkachenko/llm-skills.git ~/projects/llm-skills
```

Then, inside Claude Code: `/plugin marketplace add ~/projects/llm-skills`.

## License

MIT
