---
on:
  schedule: daily on weekdays

permissions:
  contents: read
  issues: read
  pull-requests: read

network: defaults

safe-outputs:
  create-issue:
    title-prefix: "[daily-health] "
    labels: [report, daily-health]
    close-older-issues: true
    max: 1
---

# Daily Builder Health Report

Generate a daily health report for the OpenDaylight releng/builder
repository CI infrastructure.

## Context

This repository manages CI/CD infrastructure for 25+ OpenDaylight SDN
projects using Jenkins Job Builder (JJB), Packer VM images, and GitHub
Actions workflows. Changes are reviewed on Gerrit via github2gerrit.

## Instructions

Create a concise daily health report as a GitHub issue covering:

### 1. Repository Activity (last 24h)
- Recent commits and what changed
- Open pull requests needing review
- Any CI/CD failures in recent GitHub Actions workflow runs
- Pending Gerrit changes (check open PRs as proxy)

### 2. Infrastructure Stats
- Count of JJB project directories in `jjb/`
- Count of disabled jobs (grep for `disable-job: true`)
- Count of Packer templates in `packer/templates/`
- Count of GitHub Actions workflows in `.github/workflows/`

### 3. Potential Issues
- Check for JJB files referencing deprecated build nodes
- Look for TODO/FIXME/HACK comments that need attention
- Check if submodule references (`global-jjb`, `common-packer`) are outdated
- Identify any workflows with failing status checks

### 4. Recommendations
- Flag any JJB jobs that should be disabled (inactive projects)
- Note any Packer templates that may need updating
- Suggest infrastructure improvements

### Format
Use clear headings, bullet points, and emoji status indicators:
- ✅ Healthy
- ⚠️ Needs attention
- ❌ Action required

Keep the report under 500 words. Focus on actionable items only.
