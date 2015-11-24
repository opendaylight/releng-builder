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

IFS=',' read -ra PATCHES <<< "${PATCHES_TO_BUILD}"

# for each patch, clone the project, and fetch/checkout the patch set.
# each patch is found in the ${PATCHES_TO_BUILD} variable as a comma
# separated list of project:changeset values
# Example:  PATCHES_TO_BUILD=snmp:97/27997/1,tcpmd5:91/26391/3
#
# TODO: this version will not handle multiple patches from the same project and will be
#       done at a later time.  cherry-picking will be needed, with more complex logic
#
distribution_status="not_patched"
for i in "${PATCHES[@]}"
do
    echo "working on ${i}"
    PROJECT=`echo ${i} | cut -d\: -f 1`
    if [ "${PROJECT}" == "integration/distribution" ]; then
        distribution_status="patched"
    fi
    PROJECT_SHORTNAME="${PROJECT##*/}"  # http://stackoverflow.com/a/3162500
    PATCH=`echo ${i} | cut -d\: -f 2`
    echo "<module>${PROJECT_SHORTNAME}</module>" >> $POM_FILE
    echo "cloning ${PROJECT} and checking out ${PATCH}"
    git clone https://git.opendaylight.org/gerrit/p/${PROJECT}
    cd ${PROJECT_SHORTNAME}
    git fetch https://git.opendaylight.org/gerrit/${PROJECT} refs/changes/${PATCH}
    git checkout FETCH_HEAD
    cd $BUILD_DIR
done

# finish pom file
echo "</modules>" >> $POM_FILE
echo "</project>" >> $POM_FILE

# if distribution was not cloned above, we still need to get it
if [ "${distribution_status}" == "not_patched" ]; then
    git clone https://git.opendaylight.org/gerrit/p/integration/distribution
fi

# by default we can stay in master branch or checkout something else here
if [ "${DISTRIBUTION_BRANCH_TO_BUILD}" != "master" ]; then
    cd distribution
    git checkout ${DISTRIBUTION_BRANCH_TO_BUILD}
fi


# Extract the BUNDLEVERSION from the distribution pom.xml
BUNDLEVERSION=`xpath $BUILD_DIR/distribution/pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

BUNDLEURL=${BUILD_URL}org.opendaylight.integration\$distribution-karaf/artifact/org.opendaylight.integration/distribution-karaf/${BUNDLEVERSION}/distribution-karaf-${BUNDLEVERSION}.zip
echo "Bundle url is ${BUNDLEURL}"

# Set BUNDLEVERSION & BUNDLEURL
echo BUNDLEVERSION=${BUNDLEVERSION} > ${WORKSPACE}/bundle.txt
echo BUNDLEURL=${BUNDLEURL} >> ${WORKSPACE}/bundle.txt
