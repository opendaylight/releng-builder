---
description: Safely disable Jenkins jobs using disable-job flag — never delete job definitions.
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
2. This agent's sole purpose is to **disable** jobs, never delete them.

### How to Disable a Job

Set `disable-job: true` in the project YAML file:

```yaml
# In jjb/<project>/<project>.yaml
- project:
    name: <project>-<stream>
    project: "<project>"
    project-name: "<project>"
    disable-job: true
    # ... rest of config stays intact
```

### Rules

1. **NEVER delete YAML blocks** — disabled jobs must remain in the file
   for historical reference and to preserve Jenkins build history.
2. **NEVER remove job references** from `jobs:` lists — only add
   `disable-job: true` to the project definition.
3. If disabling a specific stream (e.g., `stable/calcium`) but keeping
   others active, ensure only the targeted project block gets the flag.
4. Add a comment explaining why the job was disabled:
   ```yaml
   # Disabled: <reason> (<date>)
   disable-job: true
   ```

### Validation (REQUIRED)

After disabling, validate the change doesn't break other jobs:

```bash
jenkins-jobs test -o /tmp/jjb-output jjb/ '*<project-name>*'
```

### What This Agent Does NOT Do

- Does not delete job YAML
- Does not remove projects from the repository
- Does not modify `jjb/defaults.yaml` or `jjb/releng-templates-java.yaml`
- Does not touch `global-jjb/` submodule
