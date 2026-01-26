#!/bin/bash
# TODO: Document the default values.
NEXUSURL_PREFIX="${ODLNEXUSPROXY:-https://nexus.opendaylight.org}"
ODL_NEXUS_REPO="${ODL_NEXUS_REPO:-content/repositories/opendaylight.snapshot}"
GERRIT_PATH="${GERRIT_PATH:-git.opendaylight.org/gerrit}"
DISTROBRANCH="${DISTROBRANCH:-$GERRIT_BRANCH}"
if [ "${KARAF_ARTIFACT}" == "netconf-karaf" ] && [[ "${DISTROSTREAM}" == "titanium" ]]; then
    KARAF_PATH="karaf"
else
    KARAF_PATH="usecase/karaf"
fi

if [ "${BUNDLE_URL}" == 'last' ]; then
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
    less "maven-metadata.xml"
    # TODO: remove the second xpath command once the old version in CentOS 7 is not used any more
    TIMESTAMP=$(xpath -e "//snapshotVersion[extension='zip'][1]/value/text()" maven-metadata.xml 2>/dev/null ||
        xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null)
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
