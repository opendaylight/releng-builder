#!/bin/bash
set -xeu -o pipefail

BUNDLE_VERSION=$(xpath "${BUNDLE_POM}" '/project/version/text()' 2> /dev/null)
BUNDLE="${KARAF_ARTIFACT}-${BUNDLE_VERSION}.zip"
BUNDLE_URL="/tmp/r/org/opendaylight/integration/${KARAF_ARTIFACT}/${BUNDLE_VERSION}/${BUNDLE}"

set +e
echo "Uploading distribution to Nexus..."
"$MVN" -e -X deploy:deploy-file \
    --log-file integration-upload-distribution.log \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    -Dfile="$BUNDLE_URL" \
    -DrepositoryId=opendaylight-snapshot \
    -Durl="$ODLNEXUSPROXY/content/repositories/opendaylight.snapshot/" \
    -DgroupId="org.opendaylight.integration.${GERRIT_PROJECT//\//.}" \
    -DartifactId=${KARAF_ARTIFACT} \
    -Dversion="$BUNDLE_VERSION" \
    -Dpackaging=zip

cat "integration-upload-distribution.log"

BUNDLE_URL=$(grep "Uploaded.*${KARAF_ARTIFACT}/$BUNDLE_VERSION.*.zip" integration-upload-distribution.log | awk '{print $3}')
echo "Bundle uploaded to $BUNDLE_URL"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
env | grep BUNDLE_ | sort | tee integration-upload-distribution.env
