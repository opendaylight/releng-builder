#!/usr/bin/env bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2026 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Fail when a JJB shell fragment calls a venv-only tool without activating the
# venv that provides it.
#
# JJB runs every builder step as its own shell, so a PATH set up by an earlier
# step does not carry over. A fragment that calls lftools must therefore source
# lf-env.sh and call lf-activate-venv itself. Shellcheck cannot see this: the
# script is valid shell, it just fails at runtime with "lftools: command not
# found". That is exactly how releng-maven-mri-stage.sh shipped broken.
#
# ponytail: lftools only. It is the one tool this repo calls that is never
# installed system-wide; add to VENV_TOOLS if another venv-only tool appears.
##############################################################################

set -euo pipefail

VENV_TOOLS=(lftools)

rc=0
for file in "$@"; do
    [[ -f "$file" ]] || continue
    for tool in "${VENV_TOOLS[@]}"; do
        # Command position only: start of line or after a pipe/;/&&/||/$(.
        if ! grep -qE "(^|[|;&(]|\\\$\\()[[:space:]]*${tool}[[:space:]]" "$file"; then
            continue
        fi
        if grep -q 'lf-activate-venv' "$file"; then
            continue
        fi
        echo "ERROR: $file calls '$tool' without lf-activate-venv." >&2
        echo "       Add '. ~/lf-env.sh' and 'lf-activate-venv --python python3 $tool'." >&2
        rc=1
    done
done

exit "$rc"
