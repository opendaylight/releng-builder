#!/bin/bash

# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2019 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

echo "---> run_releasedockerhub.sh"
# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -euf -o pipefail

# shellcheck disable=SC1090
source ~/lf-env.sh

# An agent's ~/lf-env.sh is copied when it boots, so may predate lftools-uv.
if ! declare -F lftools-uv > /dev/null; then
    lf_env="$(mktemp)"
    lf_env_url="https://raw.githubusercontent.com/lfit/releng-global-jjb"
    wget -nv -O "$lf_env" "$lf_env_url/${GLOBAL_JJB_VERSION:-master}/jenkins-init-scripts/lf-env.sh" || true
    # shellcheck disable=SC1090
    source "$lf_env"
    rm -f "$lf_env"
    if ! declare -F lftools-uv > /dev/null; then
        echo "ERROR: lf-env.sh has no lftools-uv function" >&2
        exit 1
    fi
fi

if [ ! -v RELEASEDOCKERHUB_ORG ]
then
  echo "RELEASEDOCKERHUB_ORG is not defined. For onap set it to 'onap'"
  exit 1
fi

cmd_str="--org $RELEASEDOCKERHUB_ORG"
if [ -v RELEASEDOCKERHUB_SUMMARY ]
then
    cmd_str+=" --summary"
fi
if [ -v RELEASEDOCKERHUB_VERBOSE ]
then
    cmd_str+=" --verbose"
fi
if [ -v RELEASEDOCKERHUB_REPO ]
then
    cmd_str+=" --repo $RELEASEDOCKERHUB_REPO"
fi
if [ -v RELEASEDOCKERHUB_EXACT ]
then
    cmd_str+=" --exact"
fi


if [ -v RELEASEDOCKERHUB_COPY ]
then
    cmd_str+=" --copy"
fi

echo "cmd_str = >>$cmd_str<<"

# Run the releasedockerhub command in lftools-uv. The command is only in
# its Click front end, which LEGACY_CLI selects.
# shellcheck disable=SC2086
LEGACY_CLI=1 lftools-uv nexus docker releasedockerhub  $cmd_str
