# create a fresh empty place to build this custom distribution
BUILD_DIR=${WORKSPACE}/patch_tester
POM_FILE=${WORKSPACE}/patch_tester/pom.xml

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

# For each patch, clone the project.
# Optionally checkout a specific patch set.
# Also optionally, cherry-pick series of patch sets.
# Each patch is found in the ${PATCHES_TO_BUILD} variable
# as a comma separated list of project[=checkout][:cherry-pick]* values
#
# Example:  PATCHES_TO_BUILD='odlparent=45/30045/2,yangtools:53/26853/25,mdsal,controller=61/29761/5:45/29645/6,bgpcep:39/30239/1:59/30059/2'
#
distribution_status="not_included"
for patch_code in "${PATCHES[@]}"
do
    echo "working on ${patch_code}"
    PROJECT=`echo ${patch_code} | cut -d\: -f 1 | cut -d\= -f 1`
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="included"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    echo "cloning project ${PROJECT}"
    git clone https://git.opendaylight.org/gerrit/p/${PROJECT}
    echo "<module>${PROJECT_SHORTNAME}</module>" >> ${POM_FILE}
    cd ${PROJECT_SHORTNAME}
    # TODO: Add non-master branch support here.
    CHECKOUT=`echo ${patch_code} | cut -d\= -s -f 2 | cut -d\: -f 1`
    if [ "x${CHECKOUT}" != "x" ]; then
        echo "checking out ${CHECKOUT}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/$CHECKOUT"
        git checkout FETCH_HEAD
    fi
    PICK_SEGMENT=`echo "${patch_code}" | cut -d\: -s -f 2-`
    IFS=':' read -ra PICKS <<< "${PICK_SEGMENT}"
    for pick in "${PICKS[@]}"
    do
        echo "cherry-picking ${pick}"
        git fetch "https://git.opendaylight.org/gerrit/${PROJECT}" "refs/changes/${pick}"
        git cherry-pick FETCH_HEAD
    done
    cd ${BUILD_DIR}
done

if [ "${distribution_status}" == "not_included" ]; then
    echo "adding integration/distribution"
    # clone distribution and add it as a module in root pom
    git clone https://git.opendaylight.org/gerrit/p/integration/distribution
    # FIXME: Unify with Change 30105 to add support for non-master distribution branches.
    echo "<module>distribution</module>" >> ${POM_FILE}
fi

# finish pom file
echo "</modules>" >> ${POM_FILE}
echo "</project>" >> ${POM_FILE}

# Extract the BUNDLEVERSION from the distribution pom.xml
BUNDLEVERSION=`xpath $BUILD_DIR/distribution/pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

BUNDLEURL=${BUILD_URL}org.opendaylight.integration\$distribution-karaf/artifact/org.opendaylight.integration/distribution-karaf/${BUNDLEVERSION}/distribution-karaf-${BUNDLEVERSION}.zip
echo "Bundle url is ${BUNDLEURL}"

# Set BUNDLEVERSION & BUNDLEURL
echo BUNDLEVERSION=${BUNDLEVERSION} > ${WORKSPACE}/bundle.txt
echo BUNDLEURL=${BUNDLEURL} >> ${WORKSPACE}/bundle.txt