#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> update-csit-tests.sh"

# Ensure we fail the job if any steps fail.
# CSIT_BLACKLIST, SILO, STREAM are expected environment variables
set -e -o pipefail
set +u

jobs_file=$(mktemp)
search_string="csit"

wget --quiet -O "$jobs_file" https://jenkins.opendaylight.org/$SILO/api/xml
jobs=($(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' "$jobs_file" | grep $search_string | grep $STREAM))

jobs+=$(echo "$jobs" | grep -v "${CSIT_BLACKLIST// /\|}")

# output as comma-separated list
echo "${jobs[@]}" | sed 's: :,\n:g; s:^\(.*\):\1:g' > jjb/integration/csit-jobs-${STREAM}.lst
