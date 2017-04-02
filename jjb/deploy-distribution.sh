#!/bin/bash
set -xeu -o pipefail

"$MVN" deploy:deploy-file \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    -Dfile="$BUNDLE_URL" \
    -DrepositoryId=opendaylight-snapshot \
    -Durl="$ODLNEXUSPROXY/content/repositories/opendaylight.snapshot/" \
    -DgroupId="org.opendaylight.integration.${GERRIT_PROJECT//\//.}" \
    -DartifactId=distribution-karaf \
    -Dversion="$BUNDLE_VERSION" \
    -Dpackaging=zip | tee -a deploy-karaf-distribution.log

BUNDLE_URL=$(grep "Uploaded.*distribution-karaf/$BUNDLE_VERSION.*.zip" deploy-karaf-distribution.log | awk '{print $2}')
echo "Bundle uploaded to $BUNDLE_URL"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
env | grep BUNDLE_ | sort | tee deploy-distribution.env
