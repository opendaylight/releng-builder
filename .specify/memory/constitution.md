<!--
SPDX-FileCopyrightText: 2025 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# RelEng/Builder Constitution

## Core Principles

### Principle I: Infrastructure Stability

**Rule**: All changes to CI/CD infrastructure MUST be validated before
submission and MUST NOT break existing project builds.

- JJB changes MUST be validated with `jenkins-jobs test`
- Packer changes MUST be validated with `packer validate`
- GitHub workflow changes MUST pass `actionlint`
- Changes affecting multiple projects require extra scrutiny

**Rationale**: This repository controls CI/CD for 25+ OpenDaylight projects.
A broken JJB template or misconfigured workflow can halt development across
the entire organization.

### Principle II: Gerrit-First Development

**Rule**: All code changes MUST go through Gerrit code review.

- Submit via `git review` — never push directly to any branch
- GitHub is a read-only mirror
- All commits require `Signed-off-by` (DCO compliance)
- Changes must receive at least one `+2` Code-Review before merge

**Rationale**: OpenDaylight uses Gerrit as the authoritative source of truth.
GitHub mirrors exist for convenience and GitHub Actions integration only.

### Principle III: Backward Compatibility

**Rule**: Changes to shared templates MUST NOT break existing project
configurations.

- Job group changes affect ALL projects using that group
- Default parameter changes propagate to all consumers
- Use `disable-job` to deactivate jobs — never delete them
- Test with at least one project before broad rollout

**Rationale**: Shared templates (`releng-templates-java.yaml`, `defaults.yaml`)
are consumed by every ODL project. Breaking changes require coordinated
migration across all projects.

### Principle IV: Pre-Commit Integrity (NON-NEGOTIABLE)

**Rule**: Pre-commit hooks MUST pass before every submission.

- Run `pre-commit run --all-files` before `git review`
- NEVER use `--no-verify` to bypass hooks
- If a hook fails, fix the issue — do not disable the hook
- Hooks include: shellcheck, black, flake8, bandit, gitlint

**Rationale**: Automated quality gates catch issues before human review,
reducing review burden and preventing common mistakes.

### Principle V: Agent Co-Authorship & DCO Requirements (NON-NEGOTIABLE)

**Rule**: AI agent contributions MUST include proper attribution.

- All commits MUST have `Signed-off-by` line
- AI-assisted commits MUST include `Co-authored-by` trailer
- The human author is responsible for the content

**Rationale**: DCO compliance is required by the Linux Foundation.
Co-authorship provides transparency about AI involvement.

### Principle VI: Security-First Infrastructure

**Rule**: Infrastructure credentials MUST be handled securely.

- Never commit secrets, API keys, or credentials
- Use Jenkins credentials store for JJB jobs
- Use GitHub Actions secrets/vars for workflows
- Base64-encode sensitive values
- Mask credentials in workflow logs (`::add-mask::`)
- Use OAuth ephemeral keys over static credentials
- Pin all external actions to SHA commits

**Rationale**: This repository configures CI/CD with access to artifact
repositories, cloud providers, and code review systems. Credential
exposure could compromise the entire ODL infrastructure.

## Development Standards

### JJB Changes

1. Validate with `jenkins-jobs test`
2. Test on a single project before applying broadly
3. Document parameter changes in commit message
4. Use `disable-job: true` for deprecation (not deletion)

### Packer Changes

1. Validate with `packer validate`
2. Test image builds in non-production cloud first
3. Follow naming convention: `ZZCI - <os> - <variant> - <arch> - <date>`
4. Include cleanup mechanisms for failed builds

### GitHub Workflow Changes

1. Validate with `actionlint`
2. Pin actions to SHA with version comments
3. Set `timeout-minutes` on all jobs
4. Include Gerrit vote reporting (`if: always()`)

## Governance

### Amendment Process

This constitution may be amended through the standard Gerrit review process
with approval from the RelEng team. Changes to NON-NEGOTIABLE principles
require consensus from project leadership.

### Version

- **Version**: 1.0.0
- **Ratified**: 2025
- **Last Review**: 2025
