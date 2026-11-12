#!/bin/sh

echo "---> releng-maven-mri-stage.sh"
# This script publishes artifacts to a staging repo in Nexus and exports the karaf bundle URL.
#
# $WORKSPACE/m2repo   :  Exists and used to deploy the staging repository.
# $NEXUS_URL          :  Jenkins global variable should be defined.
# $STAGING_PROFILE_ID :  Provided by a job parameter.

# Ensure we fail the job if any steps fail.
# shellcheck disable=SC2039,SC3040
set -xeu -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

# An agent's ~/lf-env.sh is copied when it boots, so may predate lftools-uv.
# shellcheck disable=SC3044  # lf-env.sh is bash; see SC3040 above.
if ! declare -F lftools-uv > /dev/null; then
    lf_env="$(mktemp)"
    lf_env_url="https://raw.githubusercontent.com/lfit/releng-global-jjb"
    wget -nv -O "$lf_env" "$lf_env_url/${GLOBAL_JJB_VERSION:-master}/jenkins-init-scripts/lf-env.sh" || true
    # shellcheck disable=SC1090
    . "$lf_env"
    rm -f "$lf_env"
    # shellcheck disable=SC3044  # lf-env.sh is bash; see SC3040 above.
    if ! declare -F lftools-uv > /dev/null; then
        echo "ERROR: lf-env.sh has no lftools-uv function" >&2
        exit 1
    fi
fi

TMP_FILE="$(mktemp)"
lftools-uv deploy nexus-stage "$NEXUS_URL" "$STAGING_PROFILE_ID" "$WORKSPACE/m2repo" | tee "$TMP_FILE"
staging_repo=$(sed -n -e 's/Staging repository \(.*\) created\./\1/p' "$TMP_FILE")

# Store repo info to a file in archives
mkdir -p "$WORKSPACE/archives"
echo "$staging_repo ${NEXUS_URL}/content/repositories/$staging_repo" | tee -a "$WORKSPACE/archives/staging-repo.txt"

# TODO: remove the second xpath command once the old version in CentOS 7 is not used any more
staged_version=$(find . -name '*karaf*.pom' -exec \
    sh -c 'xpath -e "/project/version/text()" "$1" 2>/dev/null || xpath "$1" "/project/version/text()" 2>/dev/null' xpath.sh {} \;)
BUNDLE_URL="${NEXUS_URL}/content/repositories/$staging_repo/org/opendaylight/${PROJECT}/${KARAF_ARTIFACT}/${staged_version}/${KARAF_ARTIFACT}-${staged_version}.zip"

# Cleanup
rm -f "$TMP_FILE"

echo "Bundle url is ${BUNDLE_URL}"

# Re-inject the new BUNDLE_URL for downstream jobs to pull from Nexus
cat > "${WORKSPACE}/maven-staged-bundle.env" <<EOF
BUNDLE_URL=${BUNDLE_URL}
KARAF_VERSION=${KARAF_VERSION}
EOF
