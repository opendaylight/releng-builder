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

search_string="csit"

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$SILO/api/xml
jobs=($(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $search_string | grep $STREAM))

jobs+=$(echo "$jobs" | grep -v "${CSIT_BLACKLIST// /\|}")

# output as comma-separated list
echo "${jobs[@]}" | sed 's: :,\n:g; s:^\(.*\):\1:g' > jjb/integration/csit-jobs-${STREAM}.lst
