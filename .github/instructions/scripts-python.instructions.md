---
applyTo: "scripts/*.py"
---

<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# Python Script Instructions

## Standards
- Python 3.11+
- Type hints for all function parameters and returns
- SPDX header: `# SPDX-License-Identifier: EPL-1.0`
- Must pass black, flake8, and bandit

## Code Style
- Black formatter (line length 88)
- Google-style docstrings
- Imports sorted with isort

## Error Handling
- Use try/except for external calls (API, file I/O)
- Log errors with meaningful messages
- Return non-zero exit codes on failure

## Testing
- Run `tox` to execute all test environments
- Tests go in `tests/` directory alongside the script
