<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

<!--
# Sync Impact Report
**Version Change**: 0.0.0 → 1.0.0
**Change Type**: MAJOR - Initial constitution ratification

## Modified Principles
- NEW: Principle I - Gerrit Workflow
- NEW: Principle II - Submodule Boundaries
- NEW: Principle III - No Job Deletion
- NEW: Principle IV - Pre-Commit Integrity
- NEW: Principle V - License Compliance
- NEW: Principle VI - Validation Gates

## Notes
Constitution for OpenDaylight releng/builder infrastructure repository.
-->

# releng/builder Constitution

## Version: 1.0.0 | Ratified: 2026-03-25

### Principle I: Gerrit Workflow (NON-NEGOTIABLE)

**Rule**: All code changes are reviewed on Gerrit, not GitHub.

- Copilot PRs on GitHub are converted to Gerrit changes via `github2gerrit`
- Every commit MUST include DCO sign-off:
  `Signed-off-by: Anil Belur <askb23@gmail.com>`
- Conventional commit format: `Type: short imperative description`
- Allowed types (capitalized): `Fix`, `Feat`, `Chore`, `Docs`, `Style`,
  `Refactor`, `Perf`, `Test`, `Revert`, `CI`, `Build`
- Title max 72 characters, body wrap at 72 characters per line
- Changes must receive +2 Code-Review on Gerrit before merging

**Rationale**: Gerrit is the single source of truth for ODL code review.
GitHub is a read-only mirror that receives replicated merges.

### Principle II: Submodule Boundaries (NON-NEGOTIABLE)

**Rule**: NEVER modify files inside git submodules.

| Submodule Path | Upstream Repository |
|---|---|
| `global-jjb/` | https://github.com/lfit/releng-global-jjb |
| `packer/common-packer/` | https://github.com/lfit/releng-common-packer |

- The symlink `jjb/global-jjb` → `../global-jjb/jjb/` is also read-only
- If a fix requires submodule changes, **stop immediately** and respond:
  > This requires changes to `<submodule>` maintained at `<upstream-url>`.
  > Please open an issue there and update the submodule reference after
  > the fix merges upstream.
- To update a submodule version, only change the commit reference

**Rationale**: Submodules are shared across 50+ LF projects. Local
modifications would be overwritten on the next submodule update and
could break other consumers.

### Principle III: No Job Deletion (NON-NEGOTIABLE)

**Rule**: NEVER delete Jenkins job definitions. Disable them instead.

- Set `disable-job: true` in the project YAML to deprecate a job
- Deleting a job removes its build history from Jenkins permanently
- Disabled jobs are clearly visible in Jenkins UI as greyed out
- Job YAML blocks must remain in the file for historical reference

**Rationale**: Jenkins job deletion destroys build history, logs, and
artifacts. Disabled jobs preserve this data and can be re-enabled.

### Principle IV: Pre-Commit Integrity (NON-NEGOTIABLE)

**Rule**: All pre-commit hooks must pass before committing.

- Run `pre-commit run --all-files` before every commit
- Active hooks: shellcheck, yamllint, prettier, gitlint, black, flake8, bandit
- Using `--no-verify` to bypass hooks is **PROHIBITED**
- If a hook fails: fix the issue and recommit

**Rationale**: Pre-commit hooks catch syntax errors, style violations,
and security issues before they enter code review.

### Principle V: License Compliance (NON-NEGOTIABLE)

**Rule**: All new files must include EPL-1.0 SPDX headers.

```
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
```

- Use HTML comment syntax for Markdown files
- The repository license is Eclipse Public License 1.0
- OpenDaylight is an Eclipse Foundation project governed by EPL-1.0

**Rationale**: OpenDaylight is an Eclipse Foundation project governed
by EPL-1.0.

### Principle VI: Validation Gates (NON-NEGOTIABLE)

**Rule**: Validate all changes with the appropriate tooling before committing.

| Change Type | Validation Command |
|---|---|
| JJB configs | `jenkins-jobs test -o /tmp/jjb-output jjb/` |
| Packer templates | `packer validate -var-file=<vars> <template>` |
| Python scripts | `tox` |
| Shell scripts | `shellcheck <script>` |
| All files | `pre-commit run --all-files` |

- JJB validation catches YAML syntax errors and undefined variable references
- Packer validation catches template configuration errors
- Never skip validation — broken configs can take down CI for 25+ projects

**Rationale**: This repository is shared infrastructure. A broken JJB
config or Packer template affects every ODL project that depends on it.

## Governance

### Amendment Process
- **MAJOR**: New principles or behavioral changes → new version (e.g., 2.0.0)
- **MINOR**: Clarifications, expanded guidance → minor bump (e.g., 1.1.0)
- **PATCH**: Typo fixes → patch bump (e.g., 1.0.1)
- All amendments require PTL approval
