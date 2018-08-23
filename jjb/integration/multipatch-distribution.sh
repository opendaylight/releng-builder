#!/bin/bash

set -e

# create a fresh empty place to build this custom distribution
BUILD_DIR=${WORKSPACE}/patch_tester
DISTRIBUTION_BRANCH_TO_BUILD=$DISTROBRANCH  #renaming variable for clarity
MAVEN_OPTIONS="$(echo --show-version \
    --batch-mode \
    -Djenkins \
    -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    -Dmaven.repo.local=/tmp/r \
    -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r)"

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

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
if ${BUILD_FAST}; then
    fast_option="-Pq"
else
    fast_option=""
fi
# check if topic exists, e.g. topic=binding-tlc-rpc
if [[ "${PATCHES_TO_BUILD}" == *topic* ]]; then
    TOPIC="${PATCHES_TO_BUILD#*=}"
    echo "Create topic ${TOPIC} patch list"
    PATCHES_TO_BUILD=""
    read -ra PROJECT_LIST <<< "${BUILD_ORDER}"
    for PROJECT in "${PROJECT_LIST[@]}"; do
        # get all patches number for a topic for a given project
        IFS=$'\n' read -rd '' -a GERRIT_PATCH_LIST <<< "$(ssh -p 29418 jenkins-$SILO@git.opendaylight.org gerrit query status:open topic:${TOPIC} project:${PROJECT} \
        | grep 'number:' | awk '{{ print $2 }}')" || true
        # add project if it is the first with patches or it is not the first
        if [[ -z "${PATCHES_TO_BUILD}" && ! -z "${GERRIT_PATCH_LIST[*]}" ]]; then
            PATCHES_TO_BUILD="${PROJECT}"
        elif [[ ! -z "${PATCHES_TO_BUILD}" ]]; then
            if [[ ! -z "${GERRIT_PATCH_LIST[*]}" ]]; then
                echo "Add ${PROJECT}:${DISTRIBUTION_BRANCH_TO_BUILD}"
            fi
            PATCHES_TO_BUILD="${PATCHES_TO_BUILD},${PROJECT}"
        fi
        # sort project patches
        if [[ ! -z "${GERRIT_PATCH_LIST[*]}" ]]; then
            echo "Add ${PROJECT}:${GERRIT_PATCH_LIST[*]}"
            REF_LIST=()
            # create reference list with patch number-refspec
            for PATCH in "${GERRIT_PATCH_LIST[@]}"; do
                REFSPEC=$(ssh -p 29418 jenkins-$SILO@git.opendaylight.org gerrit query change:${PATCH} --current-patch-set \
                | grep 'ref:' | awk '{{ print $2 }}')
                REF_LIST+=("${PATCH}-${REFSPEC/refs\/changes\/}")
            done
            # sort reference list by patch number
            IFS=$'\n' SORT_REF=$(sort <<<"${REF_LIST[*]}") && unset IFS
            read -rd '' -a SORT_REF_LIST <<< "${SORT_REF[*]}" || true
            # add refspec to patches to build list
            for PATCH in "${SORT_REF_LIST[@]}"; do
                # if project is odlparent or yangtools, do not cherry-pick
                if [[ "${PROJECT}" == "odlparent" || "${PROJECT}" == "yangtools" ]]; then
                    PATCHES_TO_BUILD="${PATCHES_TO_BUILD}=${PATCH/*-/}"
                else
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
# 2. Optionally, checkout a specific (typically unmerged) Gerrit patch. If none,
#   default to Integration/Distribution branch via {branch} JJB param.
# 3. Also optionally, cherry-pick series of patches on top of the checkout.
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
    echo "working on ${patch}"
    # For patch=controller=61/29761/5:45/29645/6, this gives controller
    PROJECT="$(echo ${patch} | cut -d\: -f 1 | cut -d\= -f 1)"
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="included"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    PROJECTS+=("${PROJECT_SHORTNAME}")
    echo "cloning project ${PROJECT}"
    git clone "https://git.opendaylight.org/gerrit/p/${PROJECT}"
    cd ${PROJECT_SHORTNAME}
    # For patch = controller=61/29761/5:45/29645/6, this gives 61/29761/5
    CHECKOUT="$(echo ${patch} | cut -d\= -s -f 2 | cut -d\: -f 1)"
    # If project has a patch, checkout patch, otherwise use distribution branch
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "checking out ${CHECKOUT}"
        # TODO: Make this script accept "29645/6" as a shorthand for "45/29645/6".
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/$CHECKOUT"
        git checkout FETCH_HEAD

    else
        # If project with no patch = yangtools, download master branch
        if [ "${PROJECT}" == "yangtools" ]; then
            echo "checking out master"
            git checkout master
        else
            echo "checking out ${DISTRIBUTION_BRANCH_TO_BUILD}"
            git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
        fi
    fi
    # For patch=controller=61/29761/5:45/29645/6, this gives 45/29645/6
    PICK_SEGMENT="$(echo "${patch}" | cut -d\: -s -f 2-)"
    IFS=':' read -ra PICKS <<< "${PICK_SEGMENT}"
    for pick in "${PICKS[@]}"
    do
        echo "cherry-picking ${pick}"
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
    git clone "https://git.opendaylight.org/gerrit/p/integration/distribution"
    cd distribution
    git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    cd "${BUILD_DIR}"
fi

# If there is a patch for odlparent or yangtools (MRI projects), adjust version to mdsal project:
# 1. Extract project version in patch
# 2. Extract project MSI version from mdsal project
# 3. Replace version in patch by MSI version
# Otherwise release the MRI project
if [[ -d "odlparent" ]]; then
    if [[ -d "mdsal" ]]; then
        # Extract patch and MSI used version
        patch_version="$(xpath ./odlparent/odlparent-lite/pom.xml '/project/version/text()' 2> /dev/null)"
        msi_version="$(xpath ./mdsal/pom.xml '/project/parent/version/text()' 2> /dev/null)"
        # Replace version
        find ./odlparent -name "*.xml" -print0 | xargs -0 sed -i "s/${patch_version}/${msi_version}/g"
    else
        # Release project
        find ./odlparent -name "*.xml" -print0 | xargs -0 sed -i 's/-SNAPSHOT//g'
    fi
fi
if [[ -d "yangtools" ]]; then
        if [[ -d "mdsal" ]]; then
        # Extract patch and MSI used version
        patch_version="$(xpath ./yangtools/pom.xml '/project/version/text()' 2> /dev/null)"
        msi_version="$(xpath ./mdsal/binding/yang-binding/pom.xml '/project/dependencyManagement/dependencies/dependency/version/text()' 2> /dev/null)"
        # Replace version
        find ./yangtools -name "*.xml" -print0 | xargs -0 sed -i "s/${patch_version}/${msi_version}/g"
    else
        # Release project
        find ./yangtools -name "*.xml" -print0 | xargs -0 sed -i 's/-SNAPSHOT//g'
    fi
fi

# Second phase: build everything

for PROJECT_SHORTNAME in "${PROJECTS[@]}"; do
    pushd "${PROJECT_SHORTNAME}"
    # Build project
    "$MVN" clean install \
    -e ${fast_option} \
    -Dstream="$DISTROSTREAM" \
    -Dgitid.skip=false \
    -Dmaven.gitcommitid.skip=false \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    $MAVEN_OPTIONS
    # Since we've installed the artifacts, we can clean the build and save
    # disk space
    "$MVN" clean \
    -e ${fast_option} \
    -Dstream="$DISTROSTREAM" \
    -Dgitid.skip=false \
    -Dmaven.gitcommitid.skip=false \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    $MAVEN_OPTIONS
    popd
done

