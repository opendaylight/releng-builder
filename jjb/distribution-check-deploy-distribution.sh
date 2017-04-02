#!/bin/bash
set -xeu -o pipefail
GROUP_ID="org.opendaylight.${PROJECT//\//.}"
# shellcheck disable=SC1091
source /tmp/distribution-check-karaf-bundle.env

"$MVN" deploy:deploy-file \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    -Dfile="$BUNDLEURL" \
    -DrepositoryId=opendaylight-snapshot \
    -Durl="$ODLNEXUSPROXY/content/repositories/opendaylight.snapshot/" \
    -DgroupId="${GROUP_ID}.integration" \
    -DartifactId=distribution-karaf \
    -Dversion="$BUNDLEVERSION" \
    -Dpackaging=zip | tee -a deploy-karaf-distribution.log

grep "Uploaded.*distribution-karaf/$BUNDLEVERSION.*.zip" deploy-karaf-distribution.log
