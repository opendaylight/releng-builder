echo "#################################################"
echo "##       Inject Global Variables               ##"
echo "#################################################"

NEXUSURL_PREFIX="${ODLNEXUSPROXY:-https://nexus.opendaylight.org}"
ODL_NEXUS_REPO="${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}"
GERRIT_PATH="${GERRIT_PATH:-git.opendaylight.org/gerrit}"
DISTROBRANCH="${DISTROBRANCH:-$GERRIT_BRANCH}"
if [[ "$KARAF_VERSION" == "karaf3" ]]; then
    ARTIFACT="distribution-karaf"
else
    ARTIFACT="karaf"
fi

if [ ${BUNDLEURL} == 'last' ]; then
    # Obtain current pom.xml of integration/distribution, correct branch.
    wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=$(xpath pom.xml "/project/version/text()" 2> /dev/null)
    echo "Bundle version is ${BUNDLEVERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    NEXUSPATH="${NEXUSURL_PREFIX}/${ODL_NEXUS_REPO}/org/opendaylight/integration/${ARTIFACT}"
    wget "${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml"
    less "maven-metadata.xml"
    TIMESTAMP=$(xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null)
    echo "Nexus timestamp is ${TIMESTAMP}"
    BUNDLEFOLDER="${ARTIFACT}-${BUNDLEVERSION}"
    BUNDLE="${ARTIFACT}-${TIMESTAMP}.zip"
    ACTUALBUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
elif [[ "${BUNDLEURL}" == *"distribution-check"* ]]; then
    ACTUALBUNDLEURL="${BUNDLEURL}"
    BUNDLE="${BUNDLEURL##*/}"
    BUNDLEFOLDER="${BUNDLE//.zip}"
    BUNDLEVERSION="${BUNDLEFOLDER//$ARTIFACT-}"
else
    ACTUALBUNDLEURL="${BUNDLEURL}"
    BUNDLE="${BUNDLEURL##*/}"
    BUNDLEVERSION=$(basename $(dirname "${BUNDLEURL}"))
    BUNDLEFOLDER="${ARTIFACT}-${BUNDLEVERSION}"
fi

if [ "${JDKVERSION}" == 'openjdk8' ]; then
    echo "Preparing for JRE Version 8"
    JAVA_HOME="/usr/lib/jvm/java-1.8.0"
elif [ "${JDKVERSION}" == 'openjdk7' ]; then
    echo "Preparing for JRE Version 7"
    JAVA_HOME="/usr/lib/jvm/java-1.7.0"
fi

echo "Distribution bundle URL is ${ACTUALBUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution bundle version is ${BUNDLEVERSION}"
echo "Distribution folder is ${BUNDLEFOLDER}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"
echo "Java home is ${JAVA_HOME}"

cat > "${WORKSPACE}/bundle_vars.txt" <<EOF
ACTUALBUNDLEURL="${ACTUALBUNDLEURL}"
BUNDLE="${BUNDLE}"
BUNDLEVERSION="${BUNDLEVERSION}"
BUNDLEFOLDER="${BUNDLEFOLDER}"
NEXUSURL_PREFIX="${NEXUSURL_PREFIX}"
JAVA_HOME="${JAVA_HOME}"
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :

