
# Extract the BUNDLEVERSION from the pom.xml
BUNDLEVERSION=`xpath snapshot-karaf/snapshot-karaf-distribution/pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

BUNDLEURL="${BUILD_URL}artifact/snapshot-karaf/snapshot-karaf-distribution/target/snapshot-karaf-distribution-${BUNDLEVERSION}.zip"
echo "Bundle url is ${BUNDLEURL}"

# Set BUNDLEVERSION & BUNDLEURL
echo BUNDLEVERSION=${BUNDLEVERSION} > bundle.txt
echo BUNDLEURL=${BUNDLEURL} >> bundle.txt

# NOTE: BUNDLEVERSION & BUNDLEURL will be re-imported back into the environment with the
# Inject environment variables plugin (next step)
