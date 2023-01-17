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

lf-activate-venv zipp==1.1.0 lftools

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

# Run the releasedockerhub command in lftools
lftools nexus docker releasedockerhub  $cmd_str
