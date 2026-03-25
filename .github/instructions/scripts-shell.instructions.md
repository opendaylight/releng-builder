---
applyTo: "scripts/*.sh"
---

<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# Shell Script Instructions

## Required Patterns
- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- SPDX header: `# SPDX-License-Identifier: EPL-1.0`
- Must pass shellcheck with no warnings

## Context
Shell scripts in this repo serve two purposes:
- `scripts/*.sh` — Standalone automation (branch-cut, version-bump)
- Inline shell in `jjb/**/*.yaml` — Runs on Jenkins agents

For inline JJB shell, use portable Bash (no bashisms that break on
older agents). For standalone scripts, target Bash 4.4+.

## Credential Handling
- NEVER hardcode secrets in scripts
- Use Jenkins credentials injection or environment variables
- Scripts should fail fast if required variables are unset

## Error Handling
- Use `trap cleanup EXIT` for resource cleanup
- Log errors to stderr: `echo "ERROR: message" >&2`
- Return meaningful exit codes
