<!--
SPDX-FileCopyrightText: 2026 The Linux Foundation
SPDX-License-Identifier: EPL-1.0
-->

# releng/builder — Project Specification

## Overview

OpenDaylight Release Engineering Builder provides shared CI/CD
infrastructure for 25+ ODL SDN controller projects.

## Goals

1. Maintain Jenkins Job Builder (JJB) definitions for all ODL projects
2. Provide Packer VM image templates for CI build agents
3. Operate GitHub Actions workflows with Gerrit integration
4. Ensure reproducible, validated CI pipelines

## Components

### Jenkins Job Builder (JJB)
- Per-project configs: `jjb/<project>/<project>.yaml`
- Shared job groups: `jjb/releng-templates-java.yaml`
- Global defaults: `jjb/defaults.yaml`
- Macros: `jjb/releng-macros.yaml`

### Packer VM Images
- Templates: `packer/templates/*.json` (JSON format)
- Provisioning: `packer/provision/*.yaml` (Ansible)
- Shared config: `packer/common-packer/` (submodule)

### GitHub Actions
- Gerrit verify/merge pipelines
- Packer image build workflows
- Copilot coding agent infrastructure
- Agentic workflows (gh-aw)

## Constraints

- Gerrit is the code review system (not GitHub PRs)
- `global-jjb/` and `packer/common-packer/` are read-only submodules
- Jobs must never be deleted, only disabled
- EPL-1.0 license required for all files
