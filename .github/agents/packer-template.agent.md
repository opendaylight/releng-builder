---
description: Create or modify Packer VM image templates with proper validation and submodule awareness.
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
2. Read existing templates in `packer/templates/` for patterns.

### Repository Layout

```
packer/
├── templates/*.json        # Packer templates (JSON format — legacy, not HCL)
├── provision/*.yaml        # Ansible provisioning playbooks
├── vars/                   # Variable files per cloud/OS
├── common-packer/          # Git submodule — READ-ONLY
│   └── vars/               # Shared variable files
```

### Template Format

Templates are **JSON** (not HCL) — this is a legacy repository:

```json
{
  "variables": {
    "cloud_env": "{{env `CLOUDENV`}}"
  },
  "builders": [
    {
      "type": "openstack",
      "ssh_username": "ubuntu"
    }
  ],
  "provisioners": [
    {
      "type": "ansible-local",
      "playbook_file": "provision/playbook.yaml"
    }
  ]
}
```

### Rules

1. **NEVER modify `packer/common-packer/`** — it's a git submodule maintained at
   https://github.com/lfit/releng-common-packer. If changes are needed there,
   stop and tell the user to open an issue upstream.
2. Variable files in `packer/common-packer/vars/` are also read-only.
3. New templates go in `packer/templates/`.
4. New provisioning playbooks go in `packer/provision/`.
5. New variable files go in `packer/vars/`.
6. Use Ansible provisioners where possible (preferred over shell).

### Validation (REQUIRED)

After any change, validate:

```bash
cd packer
packer validate -var-file=<vars-file> templates/<template>.json
```

### Common Variables

| Variable | Description |
|----------|-------------|
| `cloud_env` | Cloud environment config (injected by CI) |
| `ssh_username` | SSH user for the base image |
| `build_timeout` | Packer build timeout |
| `distro` | OS distribution name |
