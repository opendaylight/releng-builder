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

# for each patch, clone the project, fetch/checkout the patch set.
# TODO: this version will not handle multiple patches from the same project and will be
#       done at a later time.  cherry-picking will be needed, with more complex logic
# TODO: Another enchancement will be to allow distribution patches.
for i in "${PATCHES[@]}"
do
    echo "working on ${i}"
    PROJECT=`echo ${i} | cut -d\: -f 1`
    PATCH=`echo ${i} | cut -d\: -f 2`
    echo "<module>${PROJECT}</module>" >> $POM_FILE
    echo "cloning ${PROJECT} and checking out ${PATCH}"
    git clone https://git.opendaylight.org/gerrit/p/${PROJECT}
    cd ${PROJECT}
    git fetch https://git.opendaylight.org/gerrit/${PROJECT} refs/changes/${PATCH}
    git checkout FETCH_HEAD
    cd $BUILD_DIR

done

# clone distribution and add it as a module in root pom
git clone https://git.opendaylight.org/gerrit/p/integration/distribution

echo "<module>distribution</module>" >> $POM_FILE
echo "</modules>" >> $POM_FILE
echo "</project>" >> $POM_FILE

# Extract the BUNDLEVERSION from the distribution pom.xml
BUNDLEVERSION=`xpath $BUILD_DIR/distribution/pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

BUNDLEURL=${BUILD_URL}org.opendaylight.integration\$distribution-karaf/artifact/org.opendaylight.integration/distribution-karaf/${BUNDLEVERSION}/distribution-karaf-${BUNDLEVERSION}.zip
echo "Bundle url is ${BUNDLEURL}"

# Set BUNDLEVERSION & BUNDLEURL
echo BUNDLEVERSION=${BUNDLEVERSION} > ${WORKSPACE}/bundle.txt
echo BUNDLEURL=${BUNDLEURL} >> ${WORKSPACE}/bundle.txt