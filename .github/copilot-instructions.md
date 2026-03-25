# Copilot Instructions for releng/builder

## Project Overview

This is the **OpenDaylight Release Engineering Builder** repository (`releng/builder`).
It contains Jenkins Job Builder (JJB) definitions, Packer VM image templates,
and CI/CD infrastructure for the OpenDaylight SDN controller project.

- **Primary language**: YAML (JJB), Shell (Bash), Python, HCL/JSON (Packer)
- **Code review**: Gerrit at `git.opendaylight.org` (NOT GitHub PRs directly)
- **License**: EPL-1.0
- **CI**: GitHub Actions → Gerrit verify pipeline
- **PTL**: Anil Belur

## Governance

Read `.specify/memory/constitution.md` for NON-NEGOTIABLE project principles
covering Gerrit workflow, submodule boundaries, job deletion policy, pre-commit
integrity, license compliance, and validation gates.

## Custom Agents

Use these agents for domain-specific tasks:

| Agent | Slash Command | Purpose |
|-------|--------------|---------|
| `jjb-modify` | `/jjb-modify` | Create or modify JJB project configs |
| `jjb-disable` | `/jjb-disable` | Safely disable Jenkins jobs |
| `packer-template` | `/packer-template` | Create or modify Packer templates |
| `agentic-workflows` | N/A | gh-aw workflow create/debug/upgrade |

## Repository Structure

```
jjb/                        # Jenkins Job Builder definitions
├── defaults.yaml           # Global JJB defaults (build-node, timeout, etc.)
├── releng-templates-java.yaml  # Shared Java job groups (Maven, JDK11/17/21)
├── releng-macros.yaml      # Reusable JJB macros
├── releng-jobs.yaml        # Core releng job definitions
├── <project>/<project>.yaml  # Per-project JJB configs (aaa, bgpcep, netconf, etc.)
├── global-jjb -> ../global-jjb/jjb/  # Symlink — READ-ONLY
packer/                     # VM image definitions
├── templates/*.json        # Packer templates (JSON format, legacy)
├── provision/*.yaml        # Ansible provisioning playbooks
├── common-packer/          # Git submodule — READ-ONLY
scripts/                    # Helper scripts (branch-cut, version-bump, etc.)
jenkins-config/             # Jenkins global configuration
jenkins-init-scripts/       # Jenkins agent init scripts
global-jjb/                 # Git submodule — READ-ONLY
docs/                       # Sphinx documentation
.specify/memory/            # Constitution and governance
.github/agents/             # Custom Copilot agents
.github/prompts/            # Slash-command triggers
```

## Code Review Workflow (Gerrit)

**This repo uses Gerrit, not GitHub Pull Requests.**

When Copilot creates a PR on GitHub, the `github2gerrit` workflow automatically
converts it to a Gerrit change request for review. All PRs follow this flow:

1. Copilot opens PR on GitHub
2. `github2gerrit` action pushes change to Gerrit
3. Reviewers approve on Gerrit (+2 Code-Review)
4. Change merges on Gerrit → replicates back to GitHub

### Commit Requirements

- **DCO Sign-off required**: Every commit MUST include:
  ```
  Signed-off-by: Your Name <your@email.com>
  ```
- **Conventional commit format**: `Type: short description` (capitalized type)
- **Types**: `Fix`, `Feat`, `Chore`, `Docs`, `Style`, `Refactor`, `Perf`,
  `Test`, `Revert`, `CI`, `Build`

## JJB Development

### Key Patterns

- Each ODL project has its own config: `jjb/<project>/<project>.yaml`
- Shared job groups are in `jjb/releng-templates-java.yaml`
- Global defaults are in `jjb/defaults.yaml`
- JJB macros go in `jjb/releng-macros.yaml`

### Common JJB Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `build-node` | Jenkins agent label | `centos8-builder-4c-4g` |
| `mvn-settings` | Maven settings credential | `netconf-settings` |
| `build-timeout` | Timeout in minutes | `180` |
| `java-version` | JDK version | `openjdk11`, `openjdk17`, `openjdk21` |
| `mvn-version` | Maven version | `mvn38`, `mvn39` |
| `disable-job` | Disable without deleting | `true` |

### Job Group Naming

- `odl-maven-jobs-jdk11` — Java 11 Maven jobs
- `odl-maven-jobs-jdk17` — Java 17 Maven jobs
- `odl-maven-jobs-jdk21` — Java 21 Maven jobs

## Packer Development

- Templates are JSON format in `packer/templates/`
- Variable files in `packer/vars/` and `packer/common-packer/vars/`
- Provisioning playbooks in `packer/provision/`
- Always validate: `packer validate -var-file=<vars> <template>`

## Shell Script Standards

- Use `#!/usr/bin/env bash` shebang
- Include `set -euo pipefail`
- Must pass `shellcheck` with no warnings
- SPDX header: `# SPDX-License-Identifier: EPL-1.0`

## Python Standards

- Python 3.11+
- Black formatter (line length 88)
- flake8 linting
- bandit security scanning
- Type hints preferred

## Testing Changes

1. **JJB**: `jenkins-jobs test -o /tmp/jjb-output jjb/`
2. **Pre-commit**: `pre-commit run --all-files`
3. **Tox**: `tox` (runs all test environments)
4. **Packer**: Validate changed templates with `packer validate`
