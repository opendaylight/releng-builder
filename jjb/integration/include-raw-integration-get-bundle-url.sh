#!/bin/bash
# Extract the BUNDLE_VERSION from the pom.xml
export BUNDLE_URL
export BUNDLE_VERSION
BUNDLE_VERSION=$(xpath "$BUNDLE_POM" '/project/version/text()' 2> /dev/null)
BUNDLE_URL=${BUILD_URL}org.opendaylight.integration\$distribution-karaf/artifact/org.opendaylight.integration/distribution-karaf/${BUNDLE_VERSION}/distribution-karaf-${BUNDLE_VERSION}.zip

echo "Bundle variables"
env | grep BUNDLE_ | sort | tee -a bundle.txt

# NOTE: BUNDLE_VERSION & BUNDLE_URL will be re-imported back into the environment with the
# Inject environment variables plugin (next step)
