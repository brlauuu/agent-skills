# agent-skills

Portable agent skills for [Claude Code](https://docs.claude.com/en/docs/claude-code) and [Codex CLI](https://github.com/openai/codex). Each skill is a self-contained directory under `skills/` with a `SKILL.md` (YAML frontmatter + instructions), and is consumed via symlink into the agent's skills directory.

## Repository layout

```
agent-skills/
├── skills/                 # one directory per skill, each with SKILL.md
├── scripts/install.sh      # symlink installer for Claude and Codex
├── LICENSE                 # MIT (see "License" below for alternatives)
└── README.md
```

## Skill format

Each `skills/<name>/SKILL.md` starts with YAML frontmatter:

```markdown
---
name: my-skill
description: One-sentence description with trigger phrases. Used by the agent to decide when to invoke the skill.
---

# Body in Markdown — instructions, examples, checklists...
```

Optional fields: `user_invocable: true|false`, `license`, `metadata: { author, version }`. Supporting files (scripts, references, templates) can sit alongside `SKILL.md` in the same directory.

## Installation

The installer symlinks every `skills/<name>/` into the target agent's skill directory so edits in this repo are picked up immediately.

```bash
# clone
git clone <this-repo> ~/repos/agent-skills
cd ~/repos/agent-skills

# install for both Claude and Codex (user scope: ~/.claude/skills, ~/.codex/skills)
./scripts/install.sh

# only one of them
./scripts/install.sh claude
./scripts/install.sh codex

# project scope (./.claude/skills, ./.codex/skills in $PWD)
./scripts/install.sh --project
```

After install, restart your agent so it re-scans the skills directory.

### Manual install

If you prefer no script:

```bash
ln -s "$PWD/skills/<name>" ~/.claude/skills/<name>
ln -s "$PWD/skills/<name>" ~/.codex/skills/<name>
```

### Codex notes

Codex CLI reads skill-style instructions from `~/.codex/skills/` (user) or `./.codex/skills/` (project). The `SKILL.md` format is compatible. If your Codex version expects `AGENTS.md`, you can additionally symlink/copy `SKILL.md` to `AGENTS.md` inside the skill folder.

## Included skills

| Skill | User-invocable | Description |
|---|---|---|
| [`codebase-audit`](./skills/codebase-audit/) | — | Comprehensive repository audit — architecture, docs freshness, test coverage, dead code, agent-context-file accuracy (CLAUDE.md / AGENTS.md), and dependency health. Dispatches 6 parallel tasks and writes dated reports to `docs/audit/YYYY-MM-DD/`. |
| [`issue-to-pr`](./skills/issue-to-pr/) | — | End-to-end GitHub workflow that takes an issue from assessment through implementation, testing, PR creation, review, and merge — with automatic branch cleanup. |
| [`release`](./skills/release/) | yes | Create a new project release: detect version files (`VERSION`, `package.json`, `pyproject.toml`, `Cargo.toml`, `setup.py`), bump, commit, tag, push, and publish a GitHub release with grouped notes. |
| [`repo-cleanup`](./skills/repo-cleanup/) | — | Systematic check for stale git state and Docker build waste — uncommitted files, stale branches, lingering worktrees, dangling images, build cache. |

All four are platform-neutral and run on both Claude Code and Codex CLI. `codebase-audit` documents how to dispatch parallel tasks on each platform.

### Migrating from a pre-existing `~/.claude/skills/<name>` install

The installer creates symlinks and refuses to overwrite real directories. If you already have one of these skills installed as a regular folder under `~/.claude/skills/`, remove (or rename) the original first:

```bash
rm -rf ~/.claude/skills/codebase-audit ~/.claude/skills/issue-to-pr \
       ~/.claude/skills/release ~/.claude/skills/repo-cleanup
./scripts/install.sh
```

## License

This repo is **MIT**-licensed (see [`LICENSE`](./LICENSE)). MIT is the most common choice for permissive, reuse-friendly tooling and matches what tools like Claude Code itself ship under.

If MIT does not fit your use case, common alternatives:

| License | When to pick it |
|---|---|
| **MIT** *(default here)* | Maximum permissiveness, minimal obligations. Best for broad reuse. |
| **Apache-2.0** | Like MIT, but adds an explicit patent grant and a NOTICE mechanism. Pick this if patents or contributor IP are a concern. |
| **BSD-3-Clause** | Similar to MIT, with a no-endorsement clause. Pick if you want to forbid use of your name to promote derivatives. |
| **ISC** | Functionally equivalent to MIT, slightly shorter wording. |
| **0BSD / Unlicense / CC0** | Public-domain-equivalent. Pick if you want zero attribution requirement. Note: CC0 isn't recommended for code by some communities. |
| **MPL-2.0** | Weak copyleft — file-level. Modifications to MPL files must stay open, but you can mix with proprietary code. |
| **GPL-3.0 / AGPL-3.0** | Strong copyleft. AGPL closes the SaaS loophole. Pick if you want derivatives forced open. |

To switch, replace `LICENSE` with the new text (templates at [choosealicense.com](https://choosealicense.com/)) and update this section.

## Contributing

1. Add or edit a skill under `skills/<name>/`.
2. Make sure `SKILL.md` has valid frontmatter (`name`, `description`).
3. Re-run `./scripts/install.sh` if it's a new skill.
4. Restart your agent.
