#!/bin/bash

set -e

# create a fresh empty place to build this custom distribution
BUILD_DIR=${WORKSPACE}/patch_tester
DISTRIBUTION_BRANCH_TO_BUILD=$DISTROBRANCH  #renaming variable for clarity
MAVEN_OPTIONS="${MAVEN_PARAMS} \
    --show-version \
    --batch-mode \
    -Djenkins \
    -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    -Dmaven.repo.local=/tmp/r \
    -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download distribution pom.xml
wget "http://git.opendaylight.org/gerrit/gitweb?p=integration/distribution.git;a=blob_plain;f=artifacts/upstream/properties/pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
cat pom.xml

# Set up git committer name and email, needed for commit creation when cherry-picking.
export EMAIL="sandbox@jenkins.opendaylight.org"
export GIT_COMMITTER_NAME="Multipatch Job"

# Extract a list of patches per project from an comment trigger. An example is:
# multipatch-build:openflowplugin:45/69445/1,genius:46/69446/1,netvirt:47/69447/1
if [ -n "$GERRIT_EVENT_COMMENT_TEXT" ]; then
    if [[ "$GERRIT_EVENT_COMMENT_TEXT" == *fast* ]]; then
        BUILD_FAST="true"
        PATCHES_TO_BUILD=$(echo "$GERRIT_EVENT_COMMENT_TEXT" | grep 'multipatch-build-fast:')
    else
        BUILD_FAST="false"
        PATCHES_TO_BUILD=$(echo "$GERRIT_EVENT_COMMENT_TEXT" | grep 'multipatch-build:')
    fi
    PATCHES_TO_BUILD=${PATCHES_TO_BUILD#*:}
fi
# check if topic exists:
# if topic=binding-rpc, then checkout first patch in binding-rpc topic (if it exists)
# if topic:binding-rpc, then cherry-pick first patch in binding-rpc topic (if it exists)
if [[ "${PATCHES_TO_BUILD}" == *"topic"* ]]; then
    if [[ "${PATCHES_TO_BUILD}" == *"topic="* ]]; then
        CHERRY_PICK="false"
        TOPIC="${PATCHES_TO_BUILD#*=}"
    elif [[ "${PATCHES_TO_BUILD}" == *"topic:"* ]]; then
        CHERRY_PICK="true"
        TOPIC="${PATCHES_TO_BUILD#*:}"
    else
        echo "ERROR: Topic has wrong format" && exit 1
    fi
    echo "Create topic ${TOPIC} patch list"
    PATCHES_TO_BUILD=""
    read -ra PROJECT_LIST <<< "${BUILD_ORDER}"
    echo "List of projects to check patch in topic: ${PROJECT_LIST[*]}"
    for PROJECT in "${PROJECT_LIST[@]}"; do
        # get all patches number for a topic for a given project
        IFS=$'\n' read -rd '' -a GERRIT_PATCH_LIST <<< "$(ssh -p 29418 "jenkins-$SILO@git.opendaylight.org" gerrit query status:open "topic:${TOPIC}" "project:${PROJECT}" 2> /dev/null \
        | grep 'number:' | awk '{{ print $2 }}')" || true
        # add project if it is the first with patches or it is not the first
        if [[ -z "${PATCHES_TO_BUILD}" && -n "${GERRIT_PATCH_LIST[*]}" ]]; then
            PATCHES_TO_BUILD="${PROJECT}"
        elif [[ -n "${PATCHES_TO_BUILD}" ]]; then
            if [[ -n "${GERRIT_PATCH_LIST[*]}" ]]; then
                echo "Add ${PROJECT}:${DISTRIBUTION_BRANCH_TO_BUILD}"
            fi
            PATCHES_TO_BUILD="${PATCHES_TO_BUILD},${PROJECT}"
        fi
        # sort project patches
        if [[ -n "${GERRIT_PATCH_LIST[*]}" ]]; then
            echo "Add ${PROJECT}:${GERRIT_PATCH_LIST[*]}"
            REF_LIST=()
            # create reference list with patch number-refspec
            for PATCH in "${GERRIT_PATCH_LIST[@]}"; do
                REFSPEC=$(ssh -p 29418 "jenkins-$SILO@git.opendaylight.org" gerrit query "change:${PATCH}" --current-patch-set \
                | grep 'ref:' | awk '{{ print $2 }}')
                REF_LIST+=("${PATCH}-${REFSPEC/refs\/changes\/}")
            done
            # sort reference list by patch number
            IFS=$'\n' SORT_REF=$(sort <<<"${REF_LIST[*]}") && unset IFS
            read -rd '' -a SORT_REF_LIST <<< "${SORT_REF[*]}" || true
            # add refspec to patches to build list
            COUNT=0
            for PATCH in "${SORT_REF_LIST[@]}"; do
                COUNT=$((COUNT+1))
                if [ "${COUNT}" == "1" ] && [ "${CHERRY_PICK}" == "false" ]; then
                    # checkout patch
                    PATCHES_TO_BUILD="${PATCHES_TO_BUILD}=${PATCH/*-/}"
                else
                    # cherry-pick is better than checkout patch
                    PATCHES_TO_BUILD="${PATCHES_TO_BUILD}:${PATCH/*-/}"
                fi
            done
        fi
    done
fi
echo "Patches to build: ${PATCHES_TO_BUILD}"
IFS=',' read -ra PATCHES <<< "${PATCHES_TO_BUILD}"

# First phase: clone the necessary repos and set the patches up

declare -a PROJECTS

# For each patch:
# 1. Clone the project.
# 2. Checkout an specific (typically unmerged) Gerrit patch. If none,
# use distribution pom.xml file to figure out right branch or tag to checkout.
# In case of Gerrit patch in MRI project, adjust version for the stream.
# 3. Optionally, cherry-pick series of patches on top of the checkout.
#
# Each patch is found in the ${PATCHES_TO_BUILD} variable as a comma separated
# list of project[=checkout][:cherry-pick]* values. Examples:
#
# Checkout a (typically unmerged) Gerrit patch on top of odlparent's git clone:
# PATCHES_TO_BUILD='odlparent=45/30045/2'
#
# Checkout patches for both odlparent and yangtools:
# PATCHES_TO_BUILD='odlparent=45/30045/2,yangtools:53/26853/25'
#
# Checkout a patch for controller, cherry-pick another patch on top of it:
# PATCHES_TO_BUILD='controller=61/29761/5:45/29645/6'
distribution_status="not_included"
for patch in "${PATCHES[@]}"
do
    echo "-- working on ${patch} --"
    # For patch=controller=61/29761/5:45/29645/6, this gives controller.
    PROJECT="$(echo "${patch}" | cut -d':' -f 1 | cut -d'=' -f 1)"
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="included"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    PROJECTS+=("${PROJECT_SHORTNAME}")
    echo "1. cloning project ${PROJECT}"
    git clone "https://git.opendaylight.org/gerrit/${PROJECT}"
    cd "${PROJECT_SHORTNAME}"
    # For patch = controller=61/29761/5:45/29645/6, this gives 61/29761/5.
    CHECKOUT="$(echo "${patch}" | cut -d'=' -s -f 2 | cut -d':' -f 1)"
    # If there is a base patch for this project, checkout patch, otherwise use
    # distribution pom.xml file to figure out right branch or tag to checkout.
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "2. checking out patch ${CHECKOUT}"
        # TODO: Make this script accept "29645/6" as a shorthand for "45/29645/6".
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/$CHECKOUT"
        git checkout FETCH_HEAD
        # If the patch is for MRI project, adjust the MRI versions
        # shellcheck disable=SC2235
        if [ "${PROJECT}" == "odlparent" ] || [ "${PROJECT}" == "yangtools" ] || ([ "${PROJECT}" == "mdsal" ] && [ "${DISTROSTREAM}" != "fluorine" ]); then
            ODLPARENT_VERSION="$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -v //x:odlparent.version ../pom.xml)"
            echo "change odlparent version to ${ODLPARENT_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:parent/x:groupId=\"org.opendaylight.odlparent\"\] -v "${ODLPARENT_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:groupId=\"org.opendaylight.odlparent\"\] -v "${ODLPARENT_VERSION}"
        fi
        # shellcheck disable=SC2235
        if [ "${PROJECT}" == "yangtools" ] || ([ "${PROJECT}" == "mdsal" ] && [ "${DISTROSTREAM}" != "fluorine" ]); then
            YANGTOOLS_VERSION="$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -v //x:yangtools.version ../pom.xml)"
            echo "change yangtools version to ${YANGTOOLS_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:parent/x:groupId=\"org.opendaylight.yangtools\"\] -v "${YANGTOOLS_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:groupId=\"org.opendaylight.yangtools\"\] -v "${YANGTOOLS_VERSION}"
        fi
        if [ "${PROJECT}" == "mdsal" ] && [ "${DISTROSTREAM}" != "fluorine" ]; then
            MDSAL_VERSION="$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -v //x:mdsal.version ../pom.xml)"
            echo "change mdsal version to ${MDSAL_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:parent/x:groupId=\"org.opendaylight.mdsal\"\] -v "${MDSAL_VERSION}"
            find . -name "pom.xml" -print0 | xargs -0 xmlstarlet ed --inplace -P -N x=http://maven.apache.org/POM/4.0.0 -u //x:version\[../x:groupId=\"org.opendaylight.mdsal\"\] -v "${MDSAL_VERSION}"
        fi
    else
        # If project with no patch is MRI, download release tag:
        # shellcheck disable=SC2235
        if [ "${PROJECT}" == "odlparent" ] || [ "${PROJECT}" == "yangtools" ] || ([ "${PROJECT}" == "mdsal" ] && [ "${DISTROSTREAM}" != "fluorine" ]); then
            # shellcheck disable=SC2086
            PROJECT_VERSION="$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -v //x:${PROJECT_SHORTNAME}.version ../pom.xml)"
            echo "2. checking out tag v${PROJECT_VERSION}"
            git checkout "tags/v${PROJECT_VERSION}"
        # Otherwise download distribution branch:
        else
            echo "2. checking out branch ${DISTRIBUTION_BRANCH_TO_BUILD}"
            git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
        fi
    fi
    # For patch=controller=61/29761/5:45/29645/6, this gives 45/29645/6
    PICK_SEGMENT="$(echo "${patch}" | cut -d: -s -f 2-)"
    IFS=':' read -ra PICKS <<< "${PICK_SEGMENT}"
    for pick in "${PICKS[@]}"
    do
        echo "3. cherry-picking ${pick}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/${pick}"
        git cherry-pick --ff --keep-redundant-commits FETCH_HEAD
    done
    cd "${BUILD_DIR}"
done

# Finally add distribution if there is no int/dist patch
if [ "${distribution_status}" == "not_included" ]; then
    echo "adding integration/distribution"
    PROJECTS+=(distribution)
    # clone distribution and add it as a module in root pom
    git clone "https://git.opendaylight.org/gerrit/integration/distribution"
    cd distribution
    git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    cd "${BUILD_DIR}"
fi

# Second phase: build everything

for PROJECT_SHORTNAME in "${PROJECTS[@]}"; do
    # Set Fast build if project is not in BUILD_NORMAL and BUILD_FAST is true
    if [[ "${BUILD_NORMAL}" != *"${PROJECT_SHORTNAME}"* ]] && ${BUILD_FAST}; then
        fast_option="-Pq"
    else
        fast_option=""
    fi
    pushd "${PROJECT_SHORTNAME}"
        # Build project
        "$MVN" clean install \
            -e ${fast_option} \
            -Dstream="$DISTROSTREAM" \
            -Dgitid.skip=false \
            -Dmaven.gitcommitid.skip=false \
            --global-settings "$GLOBAL_SETTINGS_FILE" \
            --settings "$SETTINGS_FILE" \
            "$MAVEN_OPTIONS"
        # Since we've installed the artifacts, we can clean the build and save
        # disk space
        "$MVN" clean \
            -e ${fast_option} \
            -Dstream="$DISTROSTREAM" \
            -Dgitid.skip=false \
            -Dmaven.gitcommitid.skip=false \
            --global-settings "$GLOBAL_SETTINGS_FILE" \
            --settings "$SETTINGS_FILE" \
            "$MAVEN_OPTIONS"
    popd
done

