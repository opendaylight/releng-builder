#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2021 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> helm-create-netrc.sh"

if [ -z "$ALT_DOCKER_URL" ]; then
    DOCKER_URL="${DOCKER_REGISTRY:-$DOCKER_URL}"
else
    DOCKER_URL="${ALT_DOCKER_URL}"
fi
CREDENTIAL=$(xmlstarlet sel -N "x=http://maven.apache.org/SETTINGS/1.0.0" \
    -t -m "/x:settings/x:servers/x:server[x:id='${SERVER_ID}']" \
    -v x:username -o ":" -v x:password \
    "$SETTINGS_FILE")

# Ensure we fail the job if any steps fail.
set -eu -o pipefail

# Handle when a project chooses to not archive logs to a log server
# in other cases if CREDENTIAL is not found then fail the build.
if [ -z "$CREDENTIAL" ] && [ "$SERVER_ID" == "logs" ]; then
    echo "WARN: Log server credential not found."
    exit 0
elif [ -z "$CREDENTIAL" ] && [ "$SERVER_ID" == "ossrh" ]; then
    echo "WARN: OSSRH credentials not found."
    echo "      This is needed for staging to Maven Central."
    exit 0
elif [ -z "$CREDENTIAL" ]; then
    echo "ERROR: Credential not found."
    exit 1
fi

if [ "$SERVER_ID" == "ossrh" ]; then
    machine="oss.sonatype.org"
else
    machine="$DOCKER_URL"
fi

user=$(echo "$CREDENTIAL" | cut -f1 -d:)
pass=$(echo "$CREDENTIAL" | cut -f2 -d:)

set +x  # Disable `set -x` to prevent printing passwords
echo "machine ${machine%:*} login $user password $pass" >> ~/.netrc
