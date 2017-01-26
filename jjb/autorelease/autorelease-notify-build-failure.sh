#!/bin/bash
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
RELEASE_EMAIL="release@lists.opendaylight.org"

ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"

BODY="Please refer to the logs server URL for console logs when possible
and use the Jenkins Build URL as a last resort.

Console Logs URL:
https://logs.opendaylight.org/$ARCHIVES_DIR

Jenkins Build URL:
$BUILD_URL"

# Get the module or project which failed
PROJECT=`zcat .archives/${ARCHIVES_DIR}/console.log.gz \
              | awk '/Reactor Summary:/{flag=1;next} \
                     /Final Memory:/{flag=0}flag'  \
              | grep '. FAILURE \[' | awk '{ print $2 }'`

# check if remote staging is complete successfully
BUILD_STATUS=`zcat .archives/${ARCHIVES_DIR}/console.log.gz \
                  | awk '/\[INFO\] Remote staging finished/{flag=1;next} \
                         /Total time:/{flag=0}flag' \
                  | grep '\] BUILD' | awk '{print $3}'`

if [ -z "${PROJECT}" ] && [[ "${BUILD_STATUS}" =~ "SUCCESS" ]]; then
	  STATUS="Success"
    ERROR_MSG=""
else
	  STATUS="Failure"
    # todo: replace the search pattern with formnat after all projects are changed
    # to "ODL :: $PROJECT :: {$projectid.$artifactId}"
    zcat .archives/${ARCHIVES_DIR}/console.log.gz \
          | awk "/\[INFO\] Building ${PROJECT} /{flag=1;next} \
                 /Reactor Summary:/{flag=0}flag" > /tmp/error_msg
fi

SUBJECT="[release] Autorelease build ${STATUS}: ${PROJECT}"

echo "${BODY}" | mail -a /tmp/error_msg -s "${SUBJECT}" "${RELEASE_EMAIL}"
