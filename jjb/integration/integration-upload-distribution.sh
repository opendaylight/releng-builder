#!/bin/bash
set -xeu -o pipefail

BUNDLE_VERSION=$(xpath "${BUNDLE_POM}" '/project/version/text()' 2> /dev/null)
BUNDLE="${KARAF_ARTIFACT}-${BUNDLE_VERSION}.zip"
BUNDLE_FILEPATH="/tmp/r/org/opendaylight/integration/${KARAF_ARTIFACT}/${BUNDLE_VERSION}/${BUNDLE}"
ls -l "${BUNDLE_FILEPATH}"
LOG_FILE='integration-upload-distribution.log'
echo "Uploading distribution to Nexus..."
"$MVN" deploy:deploy-file \
    --log-file ${LOG_FILE} \
    --global-settings "$GLOBAL_SETTINGS_FILE" \
    --settings "$SETTINGS_FILE" \
    -Dfile="${BUNDLE_FILEPATH}" \
    -DrepositoryId=opendaylight-snapshot \
    -Durl="$ODLNEXUSPROXY/content/repositories/opendaylight.snapshot/" \
    -DgroupId="org.opendaylight.integration.${GERRIT_PROJECT//\//.}" \
    -DartifactId=${KARAF_ARTIFACT} \
    -Dversion="${BUNDLE_VERSION}" \
    -Dpackaging=zip \
    || true  # Sandbox is not allowed to uplad to Nexus.

cat "${LOG_FILE}"

BUNDLE_URL=$(grep "Uploaded.*${KARAF_ARTIFACT}/${BUNDLE_VERSION}.*.zip" ${LOG_FILE} | awk '{print $3}') || true
echo "Bundle uploaded to ${BUNDLE_URL}"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
cat > "${WORKSPACE}/integration-upload-distribution.env" <<EOF
BUNDLE_URL=${BUNDLE_URL}
EOF
