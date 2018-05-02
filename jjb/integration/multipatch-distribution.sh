#!/bin/bash

# TODO: 1) clean up inline todo's below :)
# TODO: 2) Use just a topic branch to create a distribution.  see this email:
#          https://lists.opendaylight.org/pipermail/discuss/2015-December/006040.html
# TODO: 3) Bubble up CSIT jobs that are triggered by the multipatch job to a jenkins
#          parameter.  the default can be distribution-test which calls all CSIT jobs
#          but being able to easily override it to a smaller subset (or none) will be
#          helpful

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
cd $BUILD_DIR || exit 1

# Set up git committer name and email, needed for commit creation when cherry-picking.
export EMAIL="sandbox@jenkins.opendaylight.org"
export GIT_COMMITTER_NAME="Multipatch Job"

# Extract a list of patches per project from an comment trigger. An example is:
# Patch Set 1:
#
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
IFS=',' read -ra PATCHES <<< "${PATCHES_TO_BUILD}"

# First phase: clone the necessary repos and set the patches up

declare -a PROJECTS

# For each patch:
# * Clone the project.
# * Optionally, checkout a specific (typically unmerged) Gerrit patch. If none,
#   default to Integration/Distribution branch via {branch} JJB param.
# * Also optionally, cherry-pick series of patches on top of the checkout.
# * Final option: perform a 'release' by removing "-SNAPSHOT" everywhere within the project.
#
# Each patch is found in the ${PATCHES_TO_BUILD} variable as a comma separated
# list of project[=checkout][:cherry-pick]* values.
#
# Checkout a (typically unmerged) Gerrit patch on top of odlparent's git clone:
#
# PATCHES_TO_BUILD='odlparent=45/30045/2'
#
# Checkout patches for both odlparent and yangtools:
#
# PATCHES_TO_BUILD='odlparent=45/30045/2,yangtools:53/26853/25'
#
# Checkout a patch for controller, cherry-pick another patch on top of it:
#
# PATCHES_TO_BUILD='controller=61/29761/5:45/29645/6'
distribution_status="not_included"
for proto_patch in "${PATCHES[@]}"
do
    echo "working on ${proto_patch}"
    # For patch=controller=61/29761/5:45/29645/6, this gives controller
    PROJECT="$(echo ${proto_patch} | cut -d\: -f 1 | cut -d\= -f 1)"
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="included"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    PROJECTS+=("${PROJECT_SHORTNAME}")
    echo "cloning project ${PROJECT}"
    git clone "https://git.opendaylight.org/gerrit/p/${PROJECT}"
    cd ${PROJECT_SHORTNAME} || exit 1
    if [ "$(echo -n ${proto_patch} | tail -c 1)" == 'r' ]; then
        pure_patch="$(echo -n $proto_patch | head -c -1)"
    else
        pure_patch="$proto_patch"
    fi
    # For patch = controller=61/29761/5:45/29645/6, this gives 61/29761/5
    CHECKOUT="$(echo ${pure_patch} | cut -d\= -s -f 2 | cut -d\: -f 1)"
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "checking out ${CHECKOUT}"
        # TODO: Make this script accept "29645/6" as a shorthand for "45/29645/6".
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/$CHECKOUT"
        git checkout FETCH_HEAD
    else
        echo "checking out ${DISTRIBUTION_BRANCH_TO_BUILD}"
        git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    fi
    # For patch=controller=61/29761/5:45/29645/6, this gives 45/29645/6
    PICK_SEGMENT="$(echo "${pure_patch}" | cut -d\: -s -f 2-)"
    IFS=':' read -ra PICKS <<< "${PICK_SEGMENT}"
    for pick in "${PICKS[@]}"
    do
        echo "cherry-picking ${pick}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/${pick}"
        git cherry-pick --ff --keep-redundant-commits FETCH_HEAD
    done
    if [ "$(echo -n ${proto_patch} | tail -c 1)" == 'r' ]; then
        # Here 'r' means release. Useful for testing Nitrogen Odlparent changes.
        find . -name "*.xml" -print0 | xargs -0 sed -i 's/-SNAPSHOT//g'
    fi
    cd "${BUILD_DIR}" || exit 1
done

if [ "${distribution_status}" == "not_included" ]; then
    echo "adding integration/distribution"
    PROJECTS+=(distribution)
    # clone distribution and add it as a module in root pom
    git clone "https://git.opendaylight.org/gerrit/p/integration/distribution"
    cd distribution || exit 1
    git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    cd "${BUILD_DIR}" || exit 1
fi

# Second phase: calculate the build order
generateeffectivepoms() {
  for pomdir in "$@"; do
    pushd $pomdir > /dev/null || exit 1
    if grep -q '<modules>' pom.xml; then
      # In the presence of modules, we rely on mvn itself to determine which
      # modules we really need to process (depending on active profiles etc.)
      ${MVN} ${MAVEN_OPTIONS} help:effective-pom -Doutput=effective-pom.xml
      # Some projects don't generate the effective POM in the expected location
      # but their absence isn't detrimental
      if [ -f effective-pom.xml ]; then
        local -a newpomdirs=($(xmlstarlet sel -N mvn=http://maven.apache.org/POM/4.0.0 -t -m '/mvn:project/mvn:modules/mvn:module' -v . -n effective-pom.xml))
        if [[ ${#newpomdirs[@]} -gt 0 ]]; then
          for newpomdir in "${newpomdirs[@]}"; do
            generateeffectivepoms ${newpomdir}
          done
        fi
      fi
    else
      # We know we want to process this POM, but we don't need to descend
      # further
      cp pom.xml effective-pom.xml
    fi
    popd > /dev/null
  done
}
# groups maps groupIds to project shortnames
unset groups
declare -A groups
for PROJECT_SHORTNAME in "${PROJECTS[@]}"; do
  generateeffectivepoms "${PROJECT_SHORTNAME}"
  for groupId in $(find ${PROJECT_SHORTNAME} -name effective-pom.xml -exec xmlstarlet sel -N mvn=http://maven.apache.org/POM/4.0.0 -t -m '/mvn:project/mvn:groupId' -v . -n '{}' \; | sort -u); do
    groups["${groupId}"]="${PROJECT_SHORTNAME}"
  done
done
> "${BUILD_DIR}/dependencies"
for PROJECT_SHORTNAME in "${PROJECTS[@]}"; do
  unset dependencies
  declare -a dependencies
  for groupId in $(find ${PROJECT_SHORTNAME} -name effective-pom.xml -exec xmlstarlet sel -N mvn=http://maven.apache.org/POM/4.0.0 -t -m '/mvn:project/mvn:dependencies/mvn:dependency/mvn:groupId' -v . -n '{}' \; | grep org.opendaylight | sort -u); do
    if [[ "${groups[${groupId}]}" != "${PROJECT_SHORTNAME}" ]]; then
      dependencies+=("${groups[${groupId}]}")
    fi
  done
  echo ${PROJECT_SHORTNAME}: ${dependencies[*]} ${PROJECT_SHORTNAME}-stamp >> "${BUILD_DIR}/dependencies"
done

# Third phase: build everything
# We use make to process the dependencies

fast_option=-Pq

# Tabs are significant here...
cat | sed 's/    /\t/g' > Makefile <<EOF
include dependencies

%-stamp:
    cd \$* && \\
    ${MVN} clean install \\
        -e \\
        ${fast_option} \\
        -Dstream="${DISTROSTREAM}" \\
        -Dgitid.skip=false \\
        -Dmaven.gitcommitid.skip=false \\
        --global-settings "${GLOBAL_SETTINGS_FILE}" \\
        --settings "${SETTINGS_FILE}" \\
        \$(MAVEN_OPTIONS) && \\
    ${MVN} \$(MAVEN_OPTIONS) clean
    touch \$*-stamp
EOF
# In the above, we clean builds as soon as they complete because we only care
# about the installed artifacts

make distribution-stamp MAVEN_OPTIONS="${MAVEN_OPTIONS}"
