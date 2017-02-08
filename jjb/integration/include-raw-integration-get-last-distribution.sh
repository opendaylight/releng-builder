NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}
ODL_NEXUS_REPO=${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}
GERRIT_PATH=${GERRIT_PATH:-git.opendaylight.org/gerrit}
BRANCH=${GERRIT_BRANCH:-master}

# Obtain current pom.xml of integration/distribution, correct branch.
wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=pom.xml;hb=refs/heads/$BRANCH" -O "pom.xml"
# Extract the BUNDLEVERSION from the pom.xml
BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
echo "Bundle version is ${BUNDLEVERSION}"
# Acquire the timestamp information from maven-metadata.xml
NEXUSPATH="${NEXUSURL_PREFIX}/${ODL_NEXUS_REPO}/org/opendaylight/integration/distribution-karaf"
wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
less maven-metadata.xml
TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
echo "Nexus timestamp is ${TIMESTAMP}"
BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
BUNDLE="distribution-karaf-${TIMESTAMP}.zip"
ACTUALBUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"

echo "Distribution bundle URL is ${ACTUALBUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution bundle version is ${BUNDLEVERSION}"
echo "Distribution folder is ${BUNDLEFOLDER}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"

cat > ${WORKSPACE}/distribution_vars.txt <<EOF
ACTUALBUNDLEURL=${ACTUALBUNDLEURL}
BUNDLE=${BUNDLE}
BUNDLEVERSION=${BUNDLEVERSION}
BUNDLEFOLDER=${BUNDLEFOLDER}
NEXUSURL_PREFIX=${NEXUSURL_PREFIX}
JAVA_HOME=${JAVA_HOME}
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :

