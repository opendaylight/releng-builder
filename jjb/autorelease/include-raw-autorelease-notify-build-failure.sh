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

NEWLINE=$'\n'
RELEASE_EMAIL="release@lists.opendaylight.org"
ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
CONSOLE_LOG="/tmp/autorelease-build.log"
STREAM=${JOB_NAME#*-*e-}
ERROR_LOG="$WORKSPACE/error.log.gz"

# get console logs
wget -O "$CONSOLE_LOG" "${BUILD_URL}consoleText"

# TODO: This section is still required since some of the projects use
# description. Remove this section when the reactor info is more consistant.
# extract failing project from reactor information
REACTOR_INFO=$(awk '/Reactor Summary:/ { flag=1 }
          flag {
             if ( sub(/^\[(INFO)\]/,"") && sub(/FAILURE \[.*/,"") ) {
                 gsub(/[[:space:]]*::[[:space:]]*/,"::")
                 gsub(/^[[:space:]]+|[[:space:]]+$|[.]/,"")
                 print
             }
          }
          /Final Memory:/ { flag=0 }' $CONSOLE_LOG)

# check for project format
if [[ ${REACTOR_INFO} =~ .*::*.*::*. ]]; then
    # extract project and artifactId from full format
    ODL=$(echo "${REACTOR_INFO}" | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }')
    PROJECT_=$(echo "${REACTOR_INFO}" | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    NAME=$(echo "${REACTOR_INFO}" | awk -F'::' '{ gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3 }')
else
    # set project from partial format
    ODL=""
    PROJECT_=""
    NAME=$(echo "${REACTOR_INFO}" | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
fi

# determine ARTIFACT_ID for project mailing list
ARTIFACT_ID=$(awk -F: '/\[ERROR\].*mvn <goals> -rf :/ { print $2}' $CONSOLE_LOG)

# determine project mailing list using xpaths
# if project.groupId:
#     project.groupId is set and is not inherited
# else if project.parent.groupId:
#     project.groupId is not set but IS inherited from project.parent.groupId
# else
#     exclude project mailing list
if [ ! -z "$ARTIFACT_ID" ]; then
    grouplist=()
    while IFS="" read -r p; do
        GROUP=$(xmlstarlet sel\
              -N "x=http://maven.apache.org/POM/4.0.0"\
              -t -m "/x:project[x:artifactId='$ARTIFACT_ID']"\
              --if "/x:project/x:groupId"\
              -v "/x:project/x:groupId"\
              --elif "/x:project/x:parent/x:groupId"\
              -v "/x:project/x:parent/x:groupId"\
              --else -o ""\
              "$p" 2>/dev/null)
        if [ ! -z "${GROUP}" ]; then
            grouplist+=($(echo "${GROUP}" | awk -F'.' '{ print $3 }'))
        fi
    done < <(find . -name "pom.xml")

    if [ "${#grouplist[@]}" -eq 1 ]; then
        PROJECT="${grouplist[0]}"
    elif [ "${#grouplist[@]}" -gt 1 ]; then
        GROUPLIST="NOTE: The artifactId: $ARTIFACT_ID matches multiple groups: ${grouplist[*]}"
    else
        echo "Failed to determine project.groupId using xpaths"
    fi
else
    echo "Failed to determine ARTIFACT_ID"
    exit 1
fi

# Construct email subject & body
PROJECT_STRING=${PROJECT:+" from $PROJECT"}
SUBJECT="[release] Autorelease $STREAM failed to build $ARTIFACT_ID$PROJECT_STRING"
# shellcheck disable=SC2034
ATTACHMENT_INCLUDE="Attached is a snippet of the error message related to the
failure that we were able to automatically parse as well as console logs."
# shellcheck disable=SC2034
ATTACHMENT_EXCLUDE="Unable to attach error message snippet related to the failure
since this exceeds the mail server attachment size limit. Please
refer $ERROR_LOG in archives directory."
ATTACHMENT=ATTACHMENT_INCLUDE  # default behaviour
BODY="Attention ${PROJECT:-"OpenDaylight"}-devs,

Autorelease $STREAM failed to build $ARTIFACT_ID$PROJECT_STRING in build
$BUILD_NUMBER. \${!ATTACHMENT} ${PROJECT:+${NEWLINE}${GROUPLIST}}

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

if ([ ! -z "${NAME}" ] || [ ! -z "${ARTIFACT_ID}" ]) && [[ "${BUILD_STATUS}" != "SUCCESS" ]]; then
    # project search pattern should handle both scenarios
    # 1. Full format:    ODL :: $PROJECT :: $ARTIFACT_ID
    # 2. Partial format: Building $ARTIFACT_ID
    sed -e "/\[INFO\] Building \(${NAME} \|${ARTIFACT_ID} \|${ODL} :: ${PROJECT_} :: ${NAME} \)/,/Reactor Summary:/!d;//d" \
          $CONSOLE_LOG | gzip > "$ERROR_LOG"

    file_size=$(du -k "$ERROR_LOG" | cut -f1)
    if [[ "$file_size" -gt 100 ]]; then
        # shellcheck disable=SC2034
        ATTACHMENT=ATTACHMENT_EXCLUDE
    fi

    if [ -n "${PROJECT}" ]; then
        RELEASE_EMAIL="${RELEASE_EMAIL}, ${PROJECT}-dev@lists.opendaylight.org"
    fi

    # Only send emails in production (releng), not testing (sandbox)
    if [ "${SILO}" == "releng" ]; then
        MAIL_PARAMS=" -r Jenkins <jenkins-dontreply@opendaylight.org>"
        MAIL_PARAMS+=" -s \"$SUBJECT\""
        if [[ "$file_size" -gt 100 ]]; then
            MAIL_PARAMS+=" -a \"$ERROR_LOG\""
        fi
        eval echo \""${BODY}"\" | mail "$MAIL_PARAMS" "$RELEASE_EMAIL"
    elif [ "${SILO}" == "sandbox" ]; then
        echo "Running in sandbox, not actually sending notification emails"
        echo "Subject: ${SUBJECT}"
        eval echo \""Body: ${BODY}"\"
    else
        echo "Not sure how to notify in \"${SILO}\" Jenkins silo"
    fi
fi

rm $CONSOLE_LOG
