<!--
SPDX-FileCopyrightText: 2025 The Linux Foundation
SPDX-License-Identifier: Apache-2.0
-->

# Agent Development Guidelines

This document codifies git and development practices for AI agents working on
the **releng/builder** repository. These practices are derived from the project
contributing guidelines, OpenDaylight conventions, and established CI/CD
infrastructure patterns.

## Repository Overview

This is the **RelEng/Builder** repository for [OpenDaylight][odl] (ODL). It
contains:

- **Jenkins Job Builder (JJB)** templates for all ODL project CI/CD jobs
- **Packer** image definitions for OpenStack and AWS build nodes
- **GitHub Actions** workflows for Gerrit-triggered CI and image builds
- **Jenkins** configuration and initialization scripts
- **Global JJB** shared templates (git submodule at `global-jjb/`)

[odl]: https://www.opendaylight.org/

## Code Review System

This project uses **Gerrit** for code review — NOT GitHub pull requests.

- Submit changes via `git review` (not `git push`)
- All changes require Gerrit code review and verification
- GitHub is a read-only mirror; do not open pull requests

## Git Commit Message Rules

This project follows the
[seven rules of a great Git commit message](https://chris.beams.io/posts/git-commit/).

### Subject Line

- Limit the subject line to 50 characters
- Capitalize the subject line
- Do not end the subject line with a period
- Use the imperative mood ("Add", not "Added" or "Adds")
- Separate subject from body with a blank line

### Body

- Wrap the body at 72 characters per line
- Explain **what** and **why**, not how
- Reference JIRA issues where applicable (e.g., `RELENG-123`)

### Commit Types

Use conventional prefixes where appropriate:

- `feat:` — New feature or job template
- `fix:` — Bug fix in JJB config or scripts
- `docs:` — Documentation changes
- `chore:` — Maintenance (dependency updates, formatting)
- `ci:` — CI/CD workflow changes
- `refactor:` — Code restructuring without behavior change

### Sign-off

All commits MUST include a `Signed-off-by` line (DCO):

```bash
git commit -s -m "fix: correct maven merge timeout for AAA

Increase build-timeout from 60 to 180 minutes to match actual
build times observed in production.

Issue: RELENG-456
Signed-off-by: Your Name <your.email@example.com>"
```

### Co-authorship

When AI agents contribute, include the co-author trailer:

```text
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

## Repository Structure

```text
builder/
├── .github/workflows/        # GitHub Actions (Gerrit integration)
├── .pre-commit-config.yaml   # Pre-commit hooks configuration
├── global-jjb/               # Shared JJB templates (submodule)
├── jjb/                      # JJB project definitions
│   ├── defaults.yaml         # Global JJB defaults
│   ├── releng-templates-java.yaml  # ODL Java job groups
│   ├── <project>/            # Per-project JJB configs
│   │   └── <project>.yaml
│   └── global-jjb -> ../global-jjb/jjb/  # Symlink
├── jenkins-config/           # Jenkins system configuration
├── jenkins-init-scripts/     # Jenkins initialization
├── packer/                   # VM image definitions
│   ├── common-packer/        # Shared packer templates (submodule)
│   ├── provision/            # Provisioning scripts
│   ├── templates/            # HCL packer templates
│   └── vars/                 # Variable files per cloud/OS
├── scripts/                  # Helper scripts
└── tox.ini                   # Python test configuration
```

## JJB Development Standards

### File Organization

- Each ODL project has its own directory: `jjb/<project>/<project>.yaml`
- Shared job groups are in `jjb/releng-templates-java.yaml`
- Global defaults are in `jjb/defaults.yaml`
- Do NOT modify files under `jjb/global-jjb/` (managed via submodule)

### Job Template Patterns

```yaml
# Project configuration references job groups
- project:
    name: <project>-master
    jobs:
      - odl-maven-jobs-jdk21
      - odl-maven-verify-jobs-jdk21

    project: <project>
    project-name: <project>
    branch: master
    stream: master
    build-node: ubuntu2204-docker-4c-4g
    mvn-settings: "<project>-settings"
```

### Disabling Jobs

Use `disable-job: true` to disable a specific job template — do NOT delete
the job definition. This preserves rollback capability:

```yaml
- gerrit-maven-merge:
    build-timeout: 180
    disable-job: true  # Migrated to GHA
```

### Key Parameters

- `build-node` — Jenkins build agent label
- `mvn-settings` — Maven settings file name (in Jenkins credentials)
- `build-timeout` — Job timeout in minutes
- `java-version` — JDK version (e.g., `openjdk21`)
- `mvn-version` — Maven version (e.g., `mvn39`)
- `disable-job` — Set to `true` to disable without deleting

## GitHub Actions Workflow Standards

### Workflow Naming

- `gerrit-*-verify.yaml` — Gerrit patchset verification
- `gerrit-*-merge.yaml` — Post-merge CI jobs
- `gerrit-packer-*-*.yaml` — Packer image build workflows
- `openstack-cron-*.yaml` — Scheduled cleanup jobs

### Action Pinning

Pin ALL external actions to SHA commits with version comments.
Never use floating tag references:

```yaml
# ❌ Bad — floating tag
- uses: actions/checkout@v4

# ✅ Good — SHA-pinned with version comment
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

### Required Elements

- SPDX license headers at the top of every workflow file
- `yamllint disable-line rule:line-length` comments for long SHA lines
- `yamllint disable-line rule:truthy` for `on:` triggers
- `timeout-minutes` on every job to prevent runaway processes
- `concurrency` group to prevent duplicate runs

### Gerrit Integration Pattern

```yaml
on:
  workflow_dispatch:
    inputs:
      GERRIT_BRANCH:
        description: "Branch that change is against"
        required: true
        type: string
      # ... standard Gerrit inputs
```

Workflows follow a 3-4 job pipeline:

1. **prepare** — Clear Gerrit votes, allow replication
2. **build/verify/merge** — The actual CI work
3. **(optional) publish** — Artifact publishing (Nexus, etc.)
4. **vote** — Report conclusion back to Gerrit (`if: always()`)

## Packer Image Standards

### Template Format

- Use HCL format (`.pkr.hcl`) — NOT JSON
- Variable files in `packer/vars/<cloud>/<os>.pkrvars.hcl`
- Provisioning scripts in `packer/provision/`
- Common templates via `packer/common-packer/` submodule

### Naming Convention

- Image names: `ZZCI - <os> - <variant> - <arch> - <date>`
- Template files: `<os>-<variant>.pkr.hcl`
- Variable files: `<cloud>-<os>.pkrvars.hcl`

### Build Requirements

- Validate templates before submitting: `packer validate`
- Support both OpenStack and AWS builders where applicable
- Include cleanup mechanisms for failed builds
- Tag resources with `github_run_id` for traceability

## Code Quality Standards

### Pre-commit Hooks

Pre-commit hooks are configured in `.pre-commit-config.yaml`. Run before
every commit:

```bash
pre-commit run --all-files
```

Active hooks include:

- `check-json` — Validate JSON syntax
- `trailing-whitespace` — Remove trailing whitespace
- `gitlint` — Commit message validation
- `shellcheck` — Bash script linting
- `black` — Python code formatting
- `flake8` — Python linting
- `bandit` — Python security analysis

### Never Bypass Hooks

Using `--no-verify` to bypass pre-commit hooks is **PROHIBITED**.

### Shell Scripts

All bash scripts MUST:

- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` for error handling
- Pass shellcheck with no warnings
- Include SPDX license headers
- Use cleanup traps (`trap cleanup EXIT`) for resource management

### YAML Files

- Use 2-space indentation
- Must pass `yamllint` validation
- Use `---` document start marker
- Include SPDX license headers

### Python Code

- Format with `black` (line length 88)
- Lint with `flake8`
- Security scan with `bandit`
- Include type hints for function parameters and returns

## SPDX License Headers

All new files MUST include SPDX headers:

```yaml
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
```

For shell scripts:

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
```

## Testing Requirements

### JJB Validation

Validate JJB configuration before submitting:

```bash
# Test JJB parsing (requires jenkins-job-builder)
jenkins-jobs test -r jjb/ -o /tmp/jjb-output <job-name>
```

### Packer Validation

```bash
cd packer/
packer validate -var-file=vars/<cloud>/<os>.pkrvars.hcl templates/<template>.pkr.hcl
```

### GitHub Workflow Validation

```bash
# Lint all workflows
actionlint .github/workflows/*.yaml

# YAML lint
yamllint -d relaxed .github/workflows/
```

## Atomic Commits

Each commit MUST represent exactly one logical change:

- ✅ One project JJB configuration change per commit
- ✅ One packer template change per commit
- ✅ One workflow change per commit
- ❌ Multiple unrelated project changes in one commit

## Security

- Never commit secrets, credentials, or API keys
- Use Jenkins credentials store for sensitive values
- Use GitHub Actions secrets/vars for workflow credentials
- Base64-encode sensitive values in secrets
- Use `::add-mask::` in workflows to prevent credential logging
- OAuth ephemeral keys preferred over static authentication

## Development Workflow Summary

1. Clone and set up Gerrit remote
2. Create a topic branch: `git checkout -b <type>/<description>`
3. Make changes following the standards above
4. Run pre-commit hooks: `pre-commit run --all-files`
5. Validate JJB/Packer/workflows as applicable
6. Commit with sign-off: `git commit -s`
7. Submit to Gerrit: `git review`
8. Address review feedback, amend commit, re-submit

## Quick Reference

| Requirement | Command/Format |
| --- | --- |
| Sign-off | `git commit -s` |
| Co-author | `Co-authored-by: Copilot <...>` |
| Subject length | ≤50 chars |
| Body line length | ≤72 chars |
| Subject mood | Imperative ("Add", not "Added") |
| Subject punctuation | No trailing period |
| Submit for review | `git review` |
| Pre-commit | `pre-commit run --all-files` |
| JJB test | `jenkins-jobs test -r jjb/ -o /tmp/` |
| Packer validate | `packer validate <template>` |
| Workflow lint | `actionlint .github/workflows/` |
| Action pinning | `@SHA  # vX.Y.Z` (never floating tags) |
