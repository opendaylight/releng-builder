echo "#################################################"
echo "##       Inject Global Variables               ##"
echo "#################################################"

NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="${NEXUSURL_PREFIX}/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-karaf"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath distribution/pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is ${BUNDLEVERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    less maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo "Nexus timestamp is ${TIMESTAMP}"
    BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
    BUNDLE="distribution-karaf-${TIMESTAMP}.zip"
    ACTUALBUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
else
    ACTUALBUNDLEURL="${BUNDLEURL}"
    BUNDLE="${BUNDLEURL##*/}"
    BUNDLEVERSION="$(basename $(dirname $BUNDLEURL))"
    BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
fi

echo "Distribution bundle URL is ${ACTUALBUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution bundle version is ${BUNDLEVERSION}"
echo "Distribution folder is ${BUNDLEFOLDER}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"

cat > ${WORKSPACE}/bundle_vars.txt <<EOF
ACTUALBUNDLEURL=${ACTUALBUNDLEURL}
BUNDLE=${BUNDLE}
BUNDLEVERSION=${BUNDLEVERSION}
BUNDLEFOLDER=${BUNDLEFOLDER}
NEXUSURL_PREFIX=${NEXUSURL_PREFIX}
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :

