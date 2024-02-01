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
echo "---> distribution-check-verify-groupid.sh"

echo "These are allowed projects: $ALLOW_PROJECTS"
echo "These are distribution pulled projects:"
EXIT_CODE="0"
# shellcheck disable=SC2045
for PROJECT in $(ls -d /tmp/r/org/opendaylight/*); do
    echo "checking $PROJECT"
    if [[ "$ALLOW_PROJECTS" != *"$PROJECT"* ]]; then
        echo "ERROR: Not allowed project $PROJECT pulled"
        EXIT_CODE="1"
      fi
done
exit $EXIT_CODE
