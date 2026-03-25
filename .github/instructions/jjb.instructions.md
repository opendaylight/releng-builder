---
applyTo: "jjb/**"
---

# JJB File Instructions

## JJB YAML Syntax

JJB uses its own YAML-based DSL. Key differences from standard YAML:

- **Variable substitution**: Uses `{variable-name}` (single curly braces)
- **Default parameters**: Defined in `jjb/defaults.yaml`
- **Job templates**: Referenced from `global-jjb/` submodule
- **Macros**: Defined in `jjb/releng-macros.yaml`

## Project YAML Structure

Each project file (`jjb/<project>/<project>.yaml`) follows this pattern:

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

## Validation

After any change to files under `jjb/`, run:

```bash
# Test all jobs
jenkins-jobs test -o /tmp/jjb-output jjb/

# Test specific project only
jenkins-jobs test -o /tmp/jjb-output jjb/ '*<project-name>*'
```

## Rules

1. **Never modify files under `jjb/global-jjb`** — it's a symlink to the
   `global-jjb/jjb/` submodule (upstream: https://github.com/lfit/releng-global-jjb).
   If a fix requires changes here, stop and ask the user to open an issue
   on the upstream repo instead.
2. Use `disable-job: true` to disable jobs, never delete them
3. Job names follow the pattern: `<project>-<type>-<branch>-<variant>`
4. Always set `mvn-settings` for Maven jobs
5. Use the appropriate `odl-maven-jobs-jdk*` job group for the JDK version
6. Shell scripts in JJB files run on Jenkins agents — use portable Bash
