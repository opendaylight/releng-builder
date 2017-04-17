# See the macro which includes this file.

# Extract the BUNDLEVERSION from the pom.xml
BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"

BUNDLE_URL=${BUILD_URL}org.opendaylight.integration\$${KARAF_ARTIFACT}/artifact/org.opendaylight.integration/${KARAF_ARTIFACT}/${BUNDLEVERSION}/${KARAF_ARTIFACT}-${BUNDLEVERSION}.zip
echo "Bundle url is ${BUNDLE_URL}"

# Set BUNDLEVERSION & BUNDLE_URL
echo BUNDLEVERSION=${BUNDLEVERSION} > bundle.txt
echo BUNDLE_URL=${BUNDLE_URL} >> bundle.txt

# NOTE: BUNDLEVERSION & BUNDLE_URL will be re-imported back into the environment with the
# Inject environment variables plugin (next step)
