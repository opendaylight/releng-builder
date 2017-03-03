# TODO: 1) clean up inline todo's below :)
# TODO: 2) Use just a topic branch to create a distribution.  see this email:
#          https://lists.opendaylight.org/pipermail/discuss/2015-December/006040.html
# TODO: 3) Bubble up CSIT jobs that are triggered by the multipatch job to a jenkins
#          parameter.  the default can be distribution-test which calls all CSIT jobs
#          but being able to easily override it to a smaller subset (or none) will be
#          helpful

# create a fresh empty place to build this custom distribution
BUILD_DIR=${WORKSPACE}/patch_tester
POM_FILE=${WORKSPACE}/patch_tester/pom.xml
DISTRIBUTION_BRANCH_TO_BUILD=$DISTROBRANCH  #renaming variable for clarity

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# create a root pom that will contain a module for each project we have a patch for
echo "<project>" >> $POM_FILE
echo "<groupId>org.opendaylight.test</groupId>" >> $POM_FILE
echo "<artifactId>test</artifactId>" >> $POM_FILE
echo "<version>0.1</version>" >> $POM_FILE
echo "<modelVersion>4.0.0</modelVersion>" >> $POM_FILE
echo "<packaging>pom</packaging>" >> $POM_FILE
echo "<modules>" >> $POM_FILE

# Set up git committer name and email, needed for commit creation when cherry-picking.
export EMAIL="sandbox@jenkins.opendaylight.org"
# TODO: Is there a more appropriate e-mail?
export GIT_COMMITTER_NAME="Multipatch Job"

# TODO: Is "patches" still the correct word?
IFS=',' read -ra PATCHES <<< "${PATCHES_TO_BUILD}"

# For each patch:
# * Clone the project.
# * Optionally, checkout a specific (typically unmerged) Gerrit patch. If none,
#   default to Integration/Distribution branch via {branch} JJB param.
# * Also optionally, cherry-pick series of patchs on top of the checkout.
#
# Each patch is found in the ${PATCHES_TO_BUILD} variable as a comma separated
# list of project[=checkout][:cherry-pick]* values.
#
# Checkout a (typically unmerged) Gerrit patch on top of odlparent's git clone:
#
# PATCHES_TO_BUILD='odlparent=45/30045/2'
#
# Checkout patchs for both odlparent and yangtools.
#
# PATCHES_TO_BUILD='odlparent=45/30045/2,yangtools:53/26853/25'
#
# Checkout a patch for controller, cherry-pick another patch on top of it.
#
# PATCHES_TO_BUILD='controller=61/29761/5:45/29645/6'
#
# TODO: Doc how Int/Dist version is handled in both cases.

distribution_status="not_included"
for patch in "${PATCHES[@]}"
do
    echo "working on ${patch}"
    # For patch=controller=61/29761/5:45/29645/6, this gives controller
    PROJECT=`echo ${patch} | cut -d\: -f 1 | cut -d\= -f 1`
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="included"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    echo "cloning project ${PROJECT}"
    git clone "https://git.opendaylight.org/gerrit/p/${PROJECT}"
    echo "<module>${PROJECT_SHORTNAME}</module>" >> ${POM_FILE}
    cd ${PROJECT_SHORTNAME}
    # For patch=controller=61/29761/5:45/29645/6, this gives 61/29761/5
    CHECKOUT=`echo ${patch} | cut -d\= -s -f 2 | cut -d\: -f 1`
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "checking out ${CHECKOUT}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/$CHECKOUT"
        git checkout FETCH_HEAD
    else
        echo "checking out ${DISTRIBUTION_BRANCH_TO_BUILD}"
        git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    fi
    # For patch=controller=61/29761/5:45/29645/6, this gives 45/29645/6
    PICK_SEGMENT=`echo "${patch}" | cut -d\: -s -f 2-`
    IFS=':' read -ra PICKS <<< "${PICK_SEGMENT}"
    for pick in "${PICKS[@]}"
    do
        echo "cherry-picking ${pick}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/${pick}"
        git cherry-pick --ff --keep-redundant-commits FETCH_HEAD
    done
    cd "${BUILD_DIR}"
done

if [ "${distribution_status}" == "not_included" ]; then
    echo "adding integration/distribution"
    # clone distribution and add it as a module in root pom
    git clone "https://git.opendaylight.org/gerrit/p/integration/distribution"
    cd distribution
    git checkout "${DISTRIBUTION_BRANCH_TO_BUILD}"
    cd "${BUILD_DIR}"
    echo "<module>distribution</module>" >> ${POM_FILE}
fi

# finish pom file
echo "</modules>" >> ${POM_FILE}
echo "</project>" >> ${POM_FILE}
