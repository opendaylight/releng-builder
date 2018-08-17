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

jobs_file=$(mktemp)
search_string="csit"

wget --quiet -O "$jobs_file" https://jenkins.opendaylight.org/$SILO/api/xml
# shellcheck disable=SC2207
jobs=($(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' "$jobs_file" | grep $search_string | grep $STREAM))

# output as comma-separated list
job_list="${WORKSPACE}/jjb/integration/csit-jobs-${STREAM}.lst"
rm "$job_list"
for job in "${jobs[@]}"; do
    echo "$job"
    if [[ ! $job =~ update-csit-tests|${CSIT_BLACKLIST// /\|} ]]; then
        echo "    Not blacklisted, adding to ${job_list}."
        echo "${job}," >> "$job_list"
    fi
done
