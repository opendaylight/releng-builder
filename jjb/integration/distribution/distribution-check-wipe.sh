#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2024 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script performs version bumping activities for an ODL release.
echo "---> distribution-check-wipe.sh"

echo "wipe r: the local Maven repository"
rm -rfv /tmp/r
echo "wipe n: the fake remote (Nexus) repository"
rm -rfv /tmp/n
echo "wipe t: the transient repository used in some manipulations"
rm -rfv /tmp/t
echo "create n: multithreaded execution might fail at creating it."
mkdir /tmp/n
echo "detecting distribution allowed projects"
# Some allowed projects cannot be detected in distribution because they do not produce features.
ALLOW_PROJECTS=(ietf)
if [[ "$KARAF_VERSION" == "odl" ]]; then
# shellcheck disable=SC2207
ALLOW_PROJECTS+=($(grep '<groupId>org.opendaylight.' -Rh distribution \
| sed -e 's%^[ \t]*<groupId>org.opendaylight.%%' \
| sed -e 's%</groupId>%%' | sort -u))
else
# For Managed distro we only look at the features folder
# shellcheck disable=SC2207
ALLOW_PROJECTS+=($(grep '<groupId>org.opendaylight.' -Rh distribution/features \
| sed -e 's%^[ \t]*<groupId>org.opendaylight.%%' \
| sed -e 's%</groupId>%%' | sort -u))
fi
echo "Allowed projects are " "${ALLOW_PROJECTS[@]}"
echo "ALLOW_PROJECTS= " "${ALLOW_PROJECTS[@]}" > allowed_projects.txt
