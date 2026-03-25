<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# Agent Development Guidelines

## Constitution

If `.specify/memory/constitution.md` exists in this repository, read it and
follow its principles. The constitution takes precedence over this file if
there is any conflict between the two documents.

## Project Overview

OpenDaylight Release Engineering Builder repository (`releng/builder`).
Manages CI/CD infrastructure for 25+ ODL projects using Jenkins Job Builder
(JJB), Packer VM images, and GitHub Actions workflows.

**Technologies**: YAML (JJB), Shell (Bash), Python, JSON (Packer),
GitHub Actions (CI/CD), GitHub Agentic Workflows (gh-aw).

## Repository Structure

```
jjb/                        # Jenkins Job Builder definitions
├── defaults.yaml           # Global JJB defaults
├── releng-templates-java.yaml  # Shared Java job groups
├── releng-macros.yaml      # Reusable JJB macros
├── <project>/<project>.yaml  # Per-project configs
├── global-jjb -> ../global-jjb/jjb/  # Symlink (READ-ONLY)
packer/                     # VM image definitions
├── templates/*.json        # Packer templates (JSON, not HCL)
├── provision/*.yaml        # Ansible provisioning playbooks
├── common-packer/          # Git submodule (READ-ONLY)
scripts/                    # Helper scripts
.github/workflows/          # GitHub Actions CI workflows
.github/agents/             # Copilot agent definitions
.github/prompts/            # Copilot slash-command triggers
.specify/memory/            # Constitution and governance
```

## Key Conventions

### Secrets Management
- No secrets in this repository — credentials are managed by Jenkins
- Maven settings credentials referenced via `mvn-settings` parameter

### YAML Standards
- JJB YAML uses `{variable}` syntax (single braces, NOT `${{}}`)
- All YAML must pass yamllint
- YAML anchors used extensively (`&anchor` / `*anchor` / `<<: *merge`)

### Shell Scripts
- Use `#!/usr/bin/env bash` shebang
- Include `set -euo pipefail`
- Must pass shellcheck
- SPDX EPL-1.0 headers required

## Commit Conventions

This project follows the
[seven rules of a great Git commit message](https://chris.beams.io/posts/git-commit/).

### Conventional Commit Format

```plaintext
Type(scope): Short imperative description

Body explaining what and why. Wrap at 72 characters.

Co-authored-by: <AI Model Name> <appropriate-email@provider.com>
Signed-off-by: Anil Belur <askb23@gmail.com>
```

**Allowed types** (capitalized, enforced by gitlint):
`Fix`, `Feat`, `Chore`, `Docs`, `Style`, `Refactor`, `Perf`, `Test`,
`Revert`, `CI`, `Build`

### Co-Authorship

| Model   | Co-authored-by |
|---------|----------------|
| Copilot | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` |
| Claude  | `Co-authored-by: Claude <claude@anthropic.com>` |
| ChatGPT | `Co-authored-by: ChatGPT <chatgpt@openai.com>` |
| Gemini  | `Co-authored-by: Gemini <gemini@google.com>` |

### DCO Sign-off

Always use `git commit -s`: `Signed-off-by: Anil Belur <askb23@gmail.com>`

## Atomic Commits

- ✅ One JJB project change per commit
- ✅ One Packer template change per commit
- ❌ Multiple unrelated config changes in one commit

## Pre-commit

Run `pre-commit run --all-files`. Hooks: shellcheck, yamllint, prettier,
gitlint, black, flake8, bandit. Using `--no-verify` is **PROHIBITED**.

## How to Make Changes

### Adding/Modifying a JJB Project

1. Edit `jjb/<project>/<project>.yaml`
2. Reference job groups from `jjb/releng-templates-java.yaml`
3. Use parameters from `jjb/defaults.yaml`
4. Validate: `jenkins-jobs test -o /tmp/jjb-output jjb/ '*<project>*'`

### Disabling a Job

```yaml
# In jjb/<project>/<project>.yaml — NEVER delete, only disable
- project:
    name: project-name
    disable-job: true
```

### Adding a Packer Template

1. Create template in `packer/templates/<name>.json` (JSON format)
2. Add provisioning in `packer/provision/<name>.yaml`
3. Add variables if needed in `packer/vars/`
4. Validate: `cd packer && packer validate -var-file=<vars> templates/<name>.json`

## File Patterns

| Path Pattern | What It Contains |
|---|---|
| `jjb/<project>/<project>.yaml` | Per-project Jenkins job definitions |
| `jjb/releng-*.yaml` | Shared job groups, macros, templates |
| `jjb/defaults.yaml` | Global default parameters |
| `packer/templates/*.json` | Packer VM image templates |
| `packer/provision/*.yaml` | Ansible provisioning playbooks |
| `scripts/*.py` | Python automation scripts |
| `scripts/*.sh` | Shell automation scripts |
| `.github/workflows/*.yaml` | GitHub Actions CI workflows |

## Common Pitfalls

- JJB uses `{variable}` syntax (single braces), not `${{ }}` or `${}`
- `global-jjb` templates use `{project-name}` substitution from the project YAML
- Packer templates are JSON, not HCL — this is a legacy repo
- Shell scripts under `jjb/` are inlined into Jenkins jobs — test locally first
- **Never modify submodules** — see constitution Principle II

## Important Files

- `jjb/defaults.yaml` — Global JJB defaults (DO NOT change without PTL approval)
- `jjb/releng-templates-java.yaml` — Shared Maven job groups
- `.specify/memory/constitution.md` — Governance principles
- `.github/agents/agentic-workflows.agent.md` — gh-aw dispatcher
