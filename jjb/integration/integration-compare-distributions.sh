#!/bin/bash -l

# Depends on variables created and published from the integration-set-variables script

# Do not fail the build if there is trouble trying to collect distribution patch diffs
set +e

NEXUSURL_PREFIX="${ODLNEXUSPROXY:-https://nexus.opendaylight.org}"
ODL_NEXUS_REPO="${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}"
GERRIT_PATH="${GERRIT_PATH:-git.opendaylight.org/gerrit}"
DISTROBRANCH="${DISTROBRANCH:-$GERRIT_BRANCH}"
if [ "${KARAF_ARTIFACT}" == "netconf-karaf" ] && [[ "${DISTROSTREAM}" == "titanium" ]]; then
    KARAF_PATH="karaf"
else
    KARAF_PATH="usecase/karaf"
fi

# Obtain current pom.xml of integration/distribution, correct branch.
if [[ "$KARAF_ARTIFACT" == "opendaylight" ]]; then
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/integration-distribution/${DISTROBRANCH}/opendaylight/pom.xml"
elif [[ "$KARAF_ARTIFACT" == "karaf" ]]; then
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/integration-distribution/${DISTROBRANCH}/pom.xml"
elif [[ "$KARAF_ARTIFACT" == "netconf-karaf" ]]; then
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/netconf/${DISTROBRANCH}/${KARAF_PATH}/pom.xml"
elif [[ "$KARAF_ARTIFACT" == "controller-test-karaf" ]]; then
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/${KARAF_PROJECT}/${DISTROBRANCH}/karaf/pom.xml"
elif [[ "$KARAF_ARTIFACT" == "bgpcep-karaf" ]]; then
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/${KARAF_PROJECT}/${DISTROBRANCH}/distribution-karaf/pom.xml"
else
    wget -nv -O pom.xml "https://raw.githubusercontent.com/opendaylight/integration-distribution/${DISTROBRANCH}/pom.xml"
fi

# Extract the BUNDLE_VERSION from the pom.xml
# TODO: remove the second xpath command once the old version in CentOS 7 is not used any more
BUNDLE_VERSION=$(xpath -e '/project/version/text()' pom.xml 2>/dev/null ||
    xpath pom.xml '/project/version/text()' 2>/dev/null)
echo "Bundle version is ${BUNDLE_VERSION}"
# Acquire the timestamp information from maven-metadata.xml
NEXUSPATH="${NEXUSURL_PREFIX}/${ODL_NEXUS_REPO}/org/opendaylight/${KARAF_PROJECT}/${KARAF_ARTIFACT}"
wget "${NEXUSPATH}/${BUNDLE_VERSION}/maven-metadata.xml"

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  echo "unable to find maven-metadata.xml. no need to continue..."
  exit 0
fi

less maven-metadata.xml
# TODO: remove the second xpath command once the old version in CentOS 7 is not used any more
TIMESTAMP=$(xpath -e "//snapshotVersion[extension='zip'][1]/value/text()" maven-metadata.xml 2>/dev/null ||
    xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null)
echo "Nexus timestamp is ${TIMESTAMP}"
BUNDLEFOLDER="${KARAF_ARTIFACT}-${BUNDLE_VERSION}"
BUNDLE="${KARAF_ARTIFACT}-${TIMESTAMP}.zip"
ACTUAL_BUNDLE_URL="${NEXUSPATH}/${BUNDLE_VERSION}/${BUNDLE}"

wget --progress=dot:mega "$ACTUAL_BUNDLE_URL"
echo "Extracting the last distribution found on nexus..."
unzip -q "$BUNDLE"
mv "$BUNDLEFOLDER" /tmp/distro_old
rm "$BUNDLE"

echo "Extracting the distribution just created by this job..."
NEW_DISTRO="$(find "$WORKSPACE" -name "${KARAF_ARTIFACT}*.zip")"
NEW_DISTRO_BASENAME="$(basename "$NEW_DISTRO")"
cp "$NEW_DISTRO" /tmp/
cd /tmp/ || exit
unzip "$NEW_DISTRO_BASENAME"
mv "$BUNDLEFOLDER" distro_new

git clone https://git.opendaylight.org/gerrit/integration/test.git
cd test/tools/distchanges || exit
mkdir -p "$WORKSPACE"/archives

# Full output of compare tool will be in temp file /tmp/dist_diff.txt
# The file/report to be archived will only list the distribution in the comparison and the patches that
# are different.
python distcompare.py -r "ssh://jenkins-$SILO@git.opendaylight.org:29418" | tee /tmp/dist_diff.txt
echo -e "Patch differences listed are in comparison to:\n\t$ACTUAL_BUNDLE_URL\n\n" > "$WORKSPACE"/archives/distribution_differences.txt
sed -ne '/Patch differences/,$ p' /tmp/dist_diff.txt >> "$WORKSPACE"/archives/distribution_differences.txt

# Check OpenDaylight YANG modules:
echo "Installing pyang"
pip install --user pyang
if [ -f /tmp/distro_new/bin/extract_modules.sh ]; then
    echo "Extracting YANG modules"
    /tmp/distro_new/bin/extract_modules.sh
    echo "Checking YANG modules"
    /tmp/distro_new/bin/check_modules.sh
    mv /tmp/distro_new/opendaylight-models "$WORKSPACE"/archives
fi
