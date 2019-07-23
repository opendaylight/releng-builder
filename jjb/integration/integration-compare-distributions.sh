#!/bin/bash

# Depends on variables created and published from the integration-set-variables script

# Do not fail the build if there is trouble trying to collect distribution patch diffs
set +e

NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}
ODL_NEXUS_REPO=${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}
GERRIT_PATH=${GERRIT_PATH:-git.opendaylight.org/gerrit}
DISTROBRANCH=${DISTROBRANCH:-$GERRIT_BRANCH}

# Obtain current pom.xml of integration/distribution, correct branch.
if [[ "$KARAF_ARTIFACT" == "opendaylight" ]]; then
    wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=opendaylight/pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
else
    wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
fi

# Extract the BUNDLE_VERSION from the pom.xml
BUNDLE_VERSION=$(xpath pom.xml '/project/version/text()' 2> /dev/null)
echo "Bundle version is ${BUNDLE_VERSION}"
# Acquire the timestamp information from maven-metadata.xml
NEXUSPATH="${NEXUSURL_PREFIX}/${ODL_NEXUS_REPO}/org/opendaylight/integration/${KARAF_ARTIFACT}"
wget ${NEXUSPATH}/${BUNDLE_VERSION}/maven-metadata.xml

if [ $? -ne 0 ]; then
  echo "unable to find maven-metadata.xml. no need to continue..."
  exit 0
fi

less maven-metadata.xml
TIMESTAMP=$(xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null)
echo "Nexus timestamp is ${TIMESTAMP}"
BUNDLEFOLDER="${KARAF_ARTIFACT}-${BUNDLE_VERSION}"
BUNDLE="${KARAF_ARTIFACT}-${TIMESTAMP}.zip"
ACTUAL_BUNDLE_URL="${NEXUSPATH}/${BUNDLE_VERSION}/${BUNDLE}"

wget --progress=dot:mega $ACTUAL_BUNDLE_URL
echo "Extracting the last distribution found on nexus..."
unzip -q $BUNDLE
mv $BUNDLEFOLDER /tmp/distro_old
rm $BUNDLE

echo "Extracting the distribution just created by this job..."
NEW_DISTRO="$(find $WORKSPACE -name "${KARAF_ARTIFACT}*.zip")"
NEW_DISTRO_BASENAME="$(basename "$NEW_DISTRO")"
cp $NEW_DISTRO /tmp/
cd /tmp/ || exit
unzip $NEW_DISTRO_BASENAME
mv $BUNDLEFOLDER distro_new

git clone https://git.opendaylight.org/gerrit/integration/test.git
cd test/tools/distchanges || exit
mkdir -p $WORKSPACE/archives

# Full output of compare tool will be in temp file /tmp/dist_diff.txt
# The file/report to be archived will only list the distribution in the comparison and the patches that
# are different.
python distcompare.py -r ssh://jenkins-$SILO@git.opendaylight.org:29418 | tee /tmp/dist_diff.txt
echo -e "Patch differences listed are in comparison to:\n\t$ACTUAL_BUNDLE_URL\n\n" > $WORKSPACE/archives/distribution_differences.txt
sed -ne '/Patch differences/,$ p' /tmp/dist_diff.txt >> $WORKSPACE/archives/distribution_differences.txt
