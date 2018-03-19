#!/bin/bash -x
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# The script verifies non SR projects changes upstream.
# For each $SR_PROJECT patch provided in the format:
#    project=odlparent=70/45634/2,yangtools=61/76345/3
# 1. Clone $SR_PROJECT based on GERRIT_REFSPEC
# 2. Get the $SR_SNAPSHOT_VERS of the $SR_PROJECT
# 3. For each project in releng/autorelease
#    * Update the $SR_PROJECT version to the $SR_SNAPSHOT_VERS obtained from
#      step 2.
#    * Build and verify each of the projects in releng/autorelease.
# Finally exit 0 on success
# Each patch is found in the ${SR_PROJECT_CHANGE_LIST} variable as a comma separated
# list of $SR project[=checkout][:cherry-pick]* values.

echo "---> verify-sr-projects.sh"

set -eu -o pipefail

BUILD_DIR=${WORKSPACE}/SR
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR || exit 1

MAVEN_OPTIONS="$(echo --show-version \
    --batch-mode \
    -Djenkins \
    -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    -Dmaven.repo.local=/tmp/r \
    -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r)"

# Note: SR project verification is supported only from Oxygen onwards.
# Todo: Remove this check after Carbon and Nitrogen EOL
if [[ $STREAM =~ carbon ]] || [[ $STREAM =~ nitrogen ]]; then
    exit 0
fi

# List of SR project and patches to build against in the format.
# For patch=controller=61/29761/5:45/29645/6, this gives controller
if [ -n "$SR_PROJECT_CHANGE_LIST" ]; then
    SR_PROJECT_CHANGE_LIST=${SR_PROJECT_CHANGE_LIST#*:}
fi
IFS=',' read -ra PATCHES <<< "${SR_PROJECT_CHANGE_LIST}"

for patch in "${PATCHES[@]}"
do
    echo "Working on ${patch}"
    # For patch=controller=61/29761/5:45/29645/6, this gives controller
    SR_PROJECT="$(echo ${patch} | cut -d\: -f 1 | cut -d\= -f 1)"
    SR_PROJECT_SHORTNAME="${SR_PROJECT##*/}"
    echo "Cloning SR project: ${SR_PROJECT}"
    git clone "https://git.opendaylight.org/gerrit/p/${SR_PROJECT}"
    cd ${SR_PROJECT_SHORTNAME} || exit 1

    # For patch = controller=61/29761/5:45/29645/6, this gives 61/29761/5
    CHECKOUT="$(echo ${patch} | cut -d\= -s -f 2 | cut -d\: -f 1)"
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "Checking out ${CHECKOUT}"
        # For CHECKOUT = 45/29645/6, this gives 29645/6
        CHECKOUT="${CHECKOUT#*/*}"
        git config --global --add gitreview.username "jenkins-$SILO"
        git review -s
        git remote -v
        git review -d "${CHECKOUT%/*}"
    fi

    # Get snapshot version from SR project
    # SR_SNAPSHOT_VERS=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0\
    #                               -t -m "/x:project/x:version"\
    #                               -v . -n pom.xml)
    SR_SNAPSHOT_VERS=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0\
                                      -t --if "/x:project/x:version"\
                                      -v "/x:project/x:version" -n\
                                      --elif "/x:project/x:parent/x:version"\
                                      -v "/x:project/x:parent/x:version" -n\
                                      --else -o "" pom.xml)


    # Update the $SR_PROJECT version to $SR_SNAPSHOT_VERS for each project in AR
    cd ${WORKSPACE}
    for module in $(git submodule | awk '{ print $2 }'); do
        cd ${WORKSPACE}/$module
        # Find the list of pom files to change
        REGEX="<groupId>org.opendaylight.$SR_PROJECT</groupId>"
        mapfile -t POM_FILES < <(grep "$REGEX" -lR)

        # Skip the $PROJECT there are no dependencies on $SR_PROJECT
        if [ "${#POM_FILES[@]}" == 0 ]; then
            continue
        fi

        # Update pom files with $SR_SNAPSHOT_VERS
        for p in "${POM_FILES[@]}"; do
            # Check the file type is a pom file
            if [ "${p##*/}" != pom.xml ]; then
                continue
            fi
            groupId="org.opendaylight.$SR_PROJECT"
            xmlstarlet ed -L -O -P -N x=http://maven.apache.org/POM/4.0.0\
                    -u "/x:project/x:dependencyManagement/x:dependencies/x:dependency[x:groupId='$groupId']/x:version"\
                    -v "$SR_SNAPSHOT_VERS" "$p"
        done

        # print the list of files changed
        git status

        # Build project
        "$MVN" clean install \
        -e -Pq \
        -Dstream="${STREAM,,}" \
        -Dgitid.skip=false \
        -Dmaven.gitcommitid.skip=false \
        --global-settings "$GLOBAL_SETTINGS_FILE" \
        --settings "$SETTINGS_FILE" \
        $MAVEN_OPTIONS
        cd "${BUILD_DIR}" || exit 1
    done
done
