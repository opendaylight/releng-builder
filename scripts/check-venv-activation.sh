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
# Fail when a JJB shell fragment calls lftools-uv without the setup that
# provides it, or still calls legacy lftools.
#
# JJB runs every builder step as its own shell, so a PATH or a function set up
# by an earlier step does not carry over. lftools-uv is a shell function that
# lf-env.sh defines, so a fragment that calls it must source lf-env.sh itself.
# Shellcheck cannot see this: the script is valid shell, it just fails at
# runtime with "lftools-uv: command not found". That is exactly how
# releng-maven-mri-stage.sh shipped broken when it called lftools.
#
# An agent's ~/lf-env.sh is copied when it boots, so it may predate the
# lftools-uv function. Every caller must therefore also carry the fallback
# that fetches lf-env.sh at GLOBAL_JJB_VERSION, as the global-jjb scripts do.
#
# Legacy lftools is being retired and is no longer installed for these
# fragments, so calling it is always an error now.
##############################################################################

set -euo pipefail

# Command position: start of line, after a pipe/;/&&/||/$(, or after any
# leading VAR=value assignments such as the LEGACY_CLI=1 that selects
# lftools-uv's Click front end.
cmd_pos='(^|[|;&(]|\$\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'

rc=0
for file in "$@"; do
    [[ -f "$file" ]] || continue

    if grep -qE "${cmd_pos}lftools[[:space:]]" "$file"; then
        echo "ERROR: $file calls legacy 'lftools', which is retired." >&2
        echo "       Call 'lftools-uv' instead." >&2
        rc=1
    fi

    grep -qE "${cmd_pos}lftools-uv[[:space:]]" "$file" || continue

    if ! grep -qE '^[[:space:]]*(\.|source)[[:space:]]+~/lf-env\.sh' "$file"; then
        echo "ERROR: $file calls 'lftools-uv' without sourcing lf-env.sh." >&2
        echo "       Add '. ~/lf-env.sh'." >&2
        rc=1
    fi

    if ! grep -q 'declare -F lftools-uv' "$file"; then
        echo "ERROR: $file calls 'lftools-uv' without the lf-env.sh fallback." >&2
        echo "       An agent's ~/lf-env.sh may predate the lftools-uv" >&2
        echo "       function; copy the fallback the other fragments use." >&2
        rc=1
    fi
done

exit "$rc"
