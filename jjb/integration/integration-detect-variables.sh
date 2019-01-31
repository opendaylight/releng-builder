
# TODO: Document the default values.
NEXUSURL_PREFIX="${ODLNEXUSPROXY:-https://nexus.opendaylight.org}"
ODL_NEXUS_REPO="${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}"
GERRIT_PATH="${GERRIT_PATH:-git.opendaylight.org/gerrit}"
DISTROBRANCH="${DISTROBRANCH:-$GERRIT_BRANCH}"

if [ ${BUNDLE_URL} == 'last' ]; then
    # Obtain current pom.xml of integration/distribution, correct branch.
    if [[ "$KARAF_ARTIFACT" == "opendaylight" ]]; then
        wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=opendaylight/pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
    else
        wget "http://${GERRIT_PATH}/gitweb?p=integration/distribution.git;a=blob_plain;f=pom.xml;hb=refs/heads/$DISTROBRANCH" -O "pom.xml"
    fi
    # Extract the BUNDLE_VERSION from the pom.xml
    BUNDLE_VERSION="$(xpath pom.xml '/project/version/text()' 2> /dev/null)"
    echo "Bundle version is ${BUNDLE_VERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    NEXUSPATH="${NEXUSURL_PREFIX}/${ODL_NEXUS_REPO}/org/opendaylight/integration/${KARAF_ARTIFACT}"
    wget "${NEXUSPATH}/${BUNDLE_VERSION}/maven-metadata.xml"
    less "maven-metadata.xml"
    TIMESTAMP="$(xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null)"
    echo "Nexus timestamp is ${TIMESTAMP}"
    BUNDLEFOLDER="${KARAF_ARTIFACT}-${BUNDLE_VERSION}"
    BUNDLE="${KARAF_ARTIFACT}-${TIMESTAMP}.zip"
    ACTUAL_BUNDLE_URL="${NEXUSPATH}/${BUNDLE_VERSION}/${BUNDLE}"
else
    ACTUAL_BUNDLE_URL="${BUNDLE_URL}"
    BUNDLE="${BUNDLE_URL##*/}"
    ARTIFACT="$(basename "$(dirname "$(dirname "${BUNDLE_URL}")")")"
    BUNDLE_VERSION="$(basename "$(dirname "${BUNDLE_URL}")")"
    BUNDLEFOLDER="${ARTIFACT}-${BUNDLE_VERSION}"
fi

echo "Distribution bundle URL is ${ACTUAL_BUNDLE_URL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution bundle version is ${BUNDLE_VERSION}"
echo "Distribution folder is ${BUNDLEFOLDER}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"

# The following is not a shell file, double quotes would be literal.
cat > "${WORKSPACE}/detect_variables.env" <<EOF
ACTUAL_BUNDLE_URL=${ACTUAL_BUNDLE_URL}
BUNDLE=${BUNDLE}
BUNDLE_VERSION=${BUNDLE_VERSION}
BUNDLEFOLDER=${BUNDLEFOLDER}
NEXUSURL_PREFIX=${NEXUSURL_PREFIX}
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :
