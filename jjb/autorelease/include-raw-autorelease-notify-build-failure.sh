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

# todo: improve script to get the project specific email
#RELEASE_EMAIL="release@lists.opendaylight.org"
RELEASE_EMAIL="abelur@linuxfoundation.org, thanh.ha@linuxfoundation.org"
ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
CONSOLE_LOG="/tmp/autorelease-build.log"

BODY="Please refer to the logs server URL for console logs when possible
and use the Jenkins Build URL as a last resort.

Console Logs URL:
https://logs.opendaylight.org/$SILO/$ARCHIVES_DIR

Jenkins Build URL:
$BUILD_URL"

# get console logs
wget -O $CONSOLE_LOG ${BUILD_URL}consoleText

# Get the failed project artifactid
TEMP=`awk '/Reactor Summary:/{flag=1;next} \
           /Final Memory:/{flag=0}flag' $CONSOLE_LOGS \
           | grep '. FAILURE \[' | awk -F'[].]' '{gsub(/ /, "", $2); print $2 }'`

# check for project format
if [[ ${TEMP} =~ .*::*.*::*. ]]; then
    # extract project and artifactid from new format
	  PROJECT=`echo ${TEMP} | awk -F'::' '{ print $2 }'`
	  ARTIFACTID=`echo ${TEMP} |awk -F'::' '{ print $3 }'`
else
	  # set PROJECT to old project format
	  PROJECT=${TEMP}
fi

# check if remote staging is complete successfully
BUILD_STATUS=`awk '/\[INFO\] Remote staging finished/{flag=1;next} \
                   /Total time:/{flag=0}flag' $CONSOLE_LOG \
                   | grep '\] BUILD' | awk '{print $3}'`

if [ ! -z "${PROJECT}" ] && [[ "${BUILD_STATUS}" != "SUCCESS" ]]; then
    # keep the logs you send to minumum
    if [ ! -z "${ARTIFACTID}" ]; then
        PROJECT=${ARTIFACTID}
    fi

    # project search pattern should handle both scenarios
    # 1. New format
    #     "ODL :: $PROJECT :: $ARTIFACTID"
    # 2. Old format
    #     "Building ${PROJECT}"
    awk "/\[INFO\] Building ${PROJECT} / || /ODL :: ${PROJECT} :: /{flag=1;next} \
          /Reactor Summary:/{flag=0}flag" $CONSOLE_LOG > /tmp/error_msg

    SUBJECT="[release] Autorelease build failure: ${PROJECT}"
    echo "${BODY}" | mail -A /tmp/error_msg -s "${SUBJECT}" "${RELEASE_EMAIL}"
fi

rm $CONSOLE_LOG
