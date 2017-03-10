#!/bin/bash -x
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

RELEASE_EMAIL="release@lists.opendaylight.org"
ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
CONSOLE_LOG="/tmp/autorelease-build.log"
STREAM=${JOB_NAME#*-*e-}

# get console logs
wget -O "$CONSOLE_LOG" "${BUILD_URL}consoleText"

# determine artifactId
ARTIFACTID=$(awk -F: '/\[ERROR\].*mvn <goals> -rf :/ { print $2}' $CONSOLE_LOG)

# get project mailing list from the artifactId
GROUP=$($MVN help:evaluate -gs "$GLOBAL_SETTINGS_FILE" -Dexpression="project.groupId" -f $(find . -type d -name $ARTIFACTID) | grep -v Download | grep -e '^[^[]')

PROJECT=$(echo "$GROUP" | awk -F'.' { print $3 })

# Construct email subject & body
PROJECT_STRING=${PROJECT:+" from $PROJECT"}
SUBJECT="[release] Autorelease $STREAM failed to build $ARTIFACTID$PROJECT_STRING"
BODY="Attention ${PROJECT:-"OpenDaylight"}-devs,

Autorelease $STREAM failed to build $ARTIFACTID$PROJECT_STRING in build
$BUILD_NUMBER. Attached is a snippet of the error message related to the
failure that we were able to automatically parse as well as console logs.

Console Logs:
https://logs.opendaylight.org/$SILO/$ARCHIVES_DIR

Jenkins Build:
$BUILD_URL

Please review and provide an ETA on when a fix will be available.

Thanks,
ODL releng/autorelease team
"

# check if remote staging is complete successfully
BUILD_STATUS=$(awk '/\[INFO\] Remote staging finished/{flag=1;next}/Total time:/{flag=0}flag' $CONSOLE_LOG \
                   | grep '\] BUILD' | awk '{print $3}')

if [ ! -z "${ARTIFACTID}" ] && [[ "${BUILD_STATUS}" != "SUCCESS" ]]; then
    # project search pattern should handle both scenarios
    # 1. Full format:    ODL :: $PROJECT :: $ARTIFACTID
    # 2. Partial format: Building $ARTIFACTID
    sed -e "/\[INFO\] Building \(${ARTIFACTID} \|ODL :: ${PROJECT} :: ${ARTIFACTID} \)/,/Reactor Summary:/!d;//d" \
          $CONSOLE_LOG > /tmp/error.txt

    if [ -n "${PROJECT}" ]; then
        RELEASE_EMAIL="${RELEASE_EMAIL}, ${PROJECT}-dev@opendaylight.org"
    fi

    echo "${BODY}" | mail -a /tmp/error.txt \
        -r "Jenkins <jenkins-dontreply@opendaylight.org>" \
        -s "${SUBJECT}" "${RELEASE_EMAIL}"
fi

rm $CONSOLE_LOG
