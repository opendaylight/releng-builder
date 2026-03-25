---
applyTo: "packer/**"
---

<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# Packer Instructions

## Template Format
Templates are **JSON** (legacy, not HCL):
- Templates: `packer/templates/*.json`
- Variables: `packer/vars/` and `packer/common-packer/vars/`
- Provisioning: `packer/provision/*.yaml` (Ansible playbooks)

## Submodule Boundary (NON-NEGOTIABLE)
`packer/common-packer/` is a git submodule — READ-ONLY.
Never modify files inside it. If changes are needed, open an issue at
https://github.com/lfit/releng-common-packer.

## Validation
Always validate after changes:
```bash
cd packer
packer validate -var-file=<vars-file> templates/<template>.json
```

## Provisioning
- Prefer Ansible provisioners over shell provisioners
- Playbooks in `packer/provision/` use standard Ansible YAML
- Variable files define cloud-specific and OS-specific settings
