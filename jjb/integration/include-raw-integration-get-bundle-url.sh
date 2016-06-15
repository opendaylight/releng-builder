# Extract the BUNDLEVERSION from the pom.xml
BUNDLEVERSION=`xpath distribution/pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

PREFIX_EFFECTIVE="${JENKINSURL_PREFIX}/"
BUILD_URL_EFFECTIVE="${BUILD_URL/$JENKINS_URL/$PREFIX_EFFECTIVE}"
BUNDLEURL="${BUILD_URL_EFFECTIVE}org.opendaylight.integration\$distribution-karaf/artifact/org.opendaylight.integration/distribution-karaf/${BUNDLEVERSION}/distribution-karaf-${BUNDLEVERSION}.zip"
echo "Bundle url is ${BUNDLEURL}"

# Set BUNDLEVERSION & BUNDLEURL
echo BUNDLEVERSION=${BUNDLEVERSION} > bundle.txt
echo BUNDLEURL=${BUNDLEURL} >> bundle.txt

# NOTE: BUNDLEVERSION & BUNDLEURL will be re-imported back into the environment with the
# Inject environment variables plugin (next step)
