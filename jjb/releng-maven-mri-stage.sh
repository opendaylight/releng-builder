#!/bin/bash

echo "---> releng-maven-mri-stage.sh"
# This script publishes artifacts to a staging repo in Nexus and exports the karaf bundle URL.
#
# $WORKSPACE/m2repo   :  Exists and used to deploy the staging repository.
# $NEXUS_URL          :  Jenkins global variable should be defined.
# $STAGING_PROFILE_ID :  Provided by a job parameter.

# Ensure we fail the job if any steps fail.
set -xeu -o pipefail

TMP_FILE="$(mktemp)"
lftools deploy nexus-stage "$NEXUS_URL" "$STAGING_PROFILE_ID" "$WORKSPACE/m2repo" | tee "$TMP_FILE"
staging_repo=$(sed -n -e 's/Staging repository \(.*\) created\./\1/p' "$TMP_FILE")

# Store repo info to a file in archives
mkdir -p "$WORKSPACE/archives"
echo "$staging_repo ${NEXUS_URL}/content/repositories/$staging_repo" | tee -a "$WORKSPACE/archives/staging-repo.txt"

staged_version=$(find . -name '*karaf*.pom' -exec xpath -q -e '/project/version/text()' {} \;)
BUNDLE_URL="${NEXUS_URL}/content/repositories/$staging_repo/org/opendaylight/${PROJECT}/${KARAF_ARTIFACT}/${staged_version}/${KARAF_ARTIFACT}-${staged_version}.zip"

# Cleanup
rm -f "$TMP_FILE"

echo "Bundle url is ${BUNDLE_URL}"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
cat > "${WORKSPACE}/maven-staged-bundle.env" <<EOF
BUNDLE_URL=${BUNDLE_URL}
KARAF_VERSION=${KARAF_VERSION}
EOF
