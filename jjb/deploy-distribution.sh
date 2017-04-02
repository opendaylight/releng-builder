#!/bin/bash
set -xeu -o pipefail

echo "Uploading distribution to Nexus..."
"$MVN" deploy:deploy-file \
    --log-file deploy-karaf-distribution.log \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    -Dfile="$BUNDLE_URL" \
    -DrepositoryId=opendaylight-snapshot \
    -Durl="$ODLNEXUSPROXY/content/repositories/opendaylight.snapshot/" \
    -DgroupId="org.opendaylight.integration.${GERRIT_PROJECT//\//.}" \
    -DartifactId=distribution-karaf \
    -Dversion="$BUNDLE_VERSION" \
    -Dpackaging=zip

BUNDLE_URL=$(grep "Uploaded.*distribution-karaf/$BUNDLE_VERSION.*.zip" deploy-karaf-distribution.log | awk '{print $3}')
echo "Bundle uploaded to $BUNDLE_URL"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
env | grep BUNDLE_ | sort | tee deploy-distribution.env
