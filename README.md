# llm-skills

A collection of [Claude Code Skills](https://docs.claude.com/en/docs/claude-code/skills).

Each skill lives in its own folder under [`skills/`](skills/), with a `SKILL.md` orchestrator and
any resources it loads.

## Skills

| Skill | What it does |
| --- | --- |
| [`code-review`](skills/code-review/) | Structured multi-track code review (architecture, clean-code, naming, comments, readability, regression, regression-check) over your working diff or a path. Tuned for NestJS + Vue 3 + TypeScript. |

## Install

Skills load from `~/.claude/skills/<name>/`. Clone the repo and symlink the skills you want, so
`git pull` keeps the live skills up to date:

```sh
git clone https://github.com/sergeytkachenko/llm-skills.git ~/projects/llm-skills
ln -s ~/projects/llm-skills/skills/code-review ~/.claude/skills/code-review
```

See each skill's own README for usage.

## License

MIT
