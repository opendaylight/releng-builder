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
for PROJECT in $(ls /tmp/r/org/opendaylight); do
echo "checking $PROJECT"
if [[ "$ALLOW_PROJECTS" != *"$PROJECT"* ]]; then
echo "ERROR: Not allowed project $PROJECT pulled"
EXIT_CODE="1"
fi
done
exit $EXIT_CODE
echo "verify project groupId"
mkdir -p /tmp/t/org/opendaylight/{{gerrit-project}}
mv /tmp/n/org/opendaylight/{{gerrit-project}}/* /tmp/t/org/opendaylight/{{gerrit-project}}/
test -z "$(find /tmp/n/ -type f)" || ( echo "ERROR: Mismatched groupId detected (see above)." && false )
rm -rf /tmp/n
mv /tmp/t /tmp/n
