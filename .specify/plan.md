<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# releng/builder — Technical Plan

## Architecture

### CI/CD Pipeline Flow

```
Gerrit Change → github2gerrit → GitHub Actions → Gerrit Vote
                                     ↓
                              JJB Validation
                              Pre-commit Checks
                              Packer Validation
```

### Copilot Agent Architecture

```
GitHub Issue (label: copilot)
    ↓
copilot-auto-assign.yml → assigns copilot-swe-agent
    ↓
copilot-setup-steps.yml → installs JJB, pre-commit, gh-aw
    ↓
Copilot reads: constitution → agents → instructions
    ↓
Creates PR → github2gerrit → Gerrit review
```

### Agentic Workflows (gh-aw)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `builder-config-review` | PR opened/updated | JJB/Packer config review |
| `builder-daily-health` | Weekday schedule | CI health report |

## Technology Stack

- **JJB**: YAML DSL with `{variable}` substitution
- **Packer**: JSON templates (legacy, not HCL)
- **Ansible**: Provisioning playbooks
- **GitHub Actions**: CI orchestration
- **gh-aw**: Agentic workflow framework (v0.62.5)
- **Pre-commit**: Code quality gates

## Validation Strategy

All changes validated via:
1. `jenkins-jobs test` — JJB syntax and variable resolution
2. `packer validate` — Template configuration
3. `pre-commit run --all-files` — Linting (shellcheck, yamllint, etc.)
4. `tox` — Python test environments
