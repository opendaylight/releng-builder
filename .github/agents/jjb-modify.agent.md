---
description: Create or modify JJB project configurations with proper YAML structure and validation.
---

<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Guidelines

1. Load `.specify/memory/constitution.md` and follow its principles.
2. Read `jjb/defaults.yaml` to understand global default parameters.
3. Read `jjb/releng-templates-java.yaml` for available job groups.

### JJB YAML Syntax

JJB uses its own DSL — key differences from standard YAML:

- **Variable substitution**: `{variable-name}` (single curly braces, NOT `${{}}`)
- **Default parameters**: Inherited from `jjb/defaults.yaml`
- **Job templates**: Referenced from `global-jjb/` submodule (read-only)
- **Macros**: Defined in `jjb/releng-macros.yaml`
- **YAML anchors**: Used extensively — check for `&anchor` / `*anchor` / `<<: *merge`

### Project YAML Structure

Each project file follows `jjb/<project>/<project>.yaml`:

```yaml
---
- project:
    name: <project>-<stream>
    project: "<project>"
    project-name: "<project>"
    stream: <stream-name>
    branch: "master"  # or "stable/<release>"
    mvn-settings: "<project>-settings"
    build-node: centos8-builder-4c-4g
    jobs:
      - "{project-name}-maven-jobs"
      # or reference a job group:
      - odl-maven-jobs-jdk17
```

### Common Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `build-node` | Jenkins agent label | `centos8-builder-4c-4g` |
| `mvn-settings` | Maven settings credential | `netconf-settings` |
| `build-timeout` | Timeout in minutes | `180` |
| `java-version` | JDK version | `openjdk11`, `openjdk17`, `openjdk21` |
| `mvn-version` | Maven version | `mvn38`, `mvn39` |

### Job Group Naming

- `odl-maven-jobs-jdk11` — Java 11 Maven jobs
- `odl-maven-jobs-jdk17` — Java 17 Maven jobs
- `odl-maven-jobs-jdk21` — Java 21 Maven jobs

### Rules

1. **Always set `mvn-settings`** for Maven jobs — omitting it breaks the build.
2. **Never modify `jjb/global-jjb`** — it's a symlink to the `global-jjb/jjb/`
   submodule. If changes are needed there, stop and tell the user to open an
   issue at https://github.com/lfit/releng-global-jjb.
3. **Never delete job definitions** — use `disable-job: true` instead.
4. **Never modify `jjb/defaults.yaml`** without PTL approval.
5. Job names follow: `<project>-<type>-<branch>-<variant>`

### Validation (REQUIRED)

After any change, validate:

```bash
# Test all jobs
jenkins-jobs test -o /tmp/jjb-output jjb/

# Test specific project
jenkins-jobs test -o /tmp/jjb-output jjb/ '*<project-name>*'
```
