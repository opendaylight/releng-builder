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

#RELEASE_EMAIL="release@lists.opendaylight.org"
RELEASE_EMAIL="abelur@linuxfoundation.org, thanh.ha@linuxfoundation.org"
ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
CONSOLE_LOG="/tmp/autorelease-build.log"
STREAM=${JOB_NAME#*-*e-}

BODY="Please refer to the logs server URL for console logs when possible
and use the Jenkins Build URL as a last resort.

Console Logs URL:
https://logs.opendaylight.org/$SILO/$ARCHIVES_DIR

Jenkins Build URL:
$BUILD_URL"

# get console logs
wget -O $CONSOLE_LOG ${BUILD_URL}consoleText

# extract the failing project or artifactid
REACTOR_INFO=`awk '/Reactor Summary:/ { flag=1 }
          flag {
             if ( sub(/^\[(INFO)\]/,"") && sub(/FAILURE \[.*/,"") ) {
                 gsub(/[[:space:]]*::[[:space:]]*/,"::")
                 gsub(/^[[:space:]]+|[[:space:]]+$|[.]/,"")
                 print
             }
          }
          /Final Memory:/ { flag=0 }' $CONSOLE_LOG`

# check for project format
if [[ ${REACTOR_INFO} =~ .*::*.*::*. ]]; then
    # extract project and artifactid from full format
    ODL=`echo ${REACTOR_INFO} | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }'`
    PROJECT=`echo ${REACTOR_INFO} | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }'`
    ARTIFACTID=`echo ${REACTOR_INFO} | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3 }'`
else
    # set ARTIFACTID to partial format
    ODL=""
    PROJECT=""
    ARTIFACTID=`echo ${REACTOR_INFO} | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }'`
fi

# check if remote staging is complete successfully
BUILD_STATUS=`awk '/\[INFO\] Remote staging finished/{flag=1;next} \
                   /Total time:/{flag=0}flag' $CONSOLE_LOG \
                   | grep '\] BUILD' | awk '{print $3}'`

if [ ! -z "${ARTIFACTID}" ] && [[ "${BUILD_STATUS}" != "SUCCESS" ]]; then
    # project search pattern should handle both scenarios
    # 1. Full format:    ODL :: $PROJECT :: $ARTIFACTID
    # 2. Partial format: Building $ARTIFACTID
    sed -e "/\[INFO\] Building \(${ARTIFACTID} \|${ODL} :: ${PROJECT} :: ${ARTIFACTID} \)/,/Reactor Summary:/!d;//d" \
          $CONSOLE_LOG > /tmp/error_msg

    if [ -z "${PROJECT}" ]; then
        PROJECT=${ARTIFACTID}
        # TODO: unset the below line when ready to deploy to real lists
        # RELEASE_EMAIL = "${RELEASE_EMAIL}, ${PROJECT}-dev@opendaylight.org"
    fi

    SUBJECT="[release] Autorelease ${STREAM} build failure: ${PROJECT}"

    echo "${BODY}" | mail -a /tmp/error_msg -s "${SUBJECT}" "${RELEASE_EMAIL}"
fi

rm $CONSOLE_LOG
