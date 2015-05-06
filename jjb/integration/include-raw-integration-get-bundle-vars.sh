echo "#################################################"
echo "## include-raw-integration-get-bundle_vars.txt ##"
echo "#################################################"
set -x
# Create a script to run controller inside a dynamic jenkins slave
CONTROLLERMEM="2048m"
DISTRIBUTION="karaf"



if [ ${CONTROLLERSCOPE} == 'all' ]; then
    CONTROLLERFEAT="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
else
    CONTROLLERFEAT="${CONTROLLERFEATURES}"
fi

NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="${NEXUSURL_PREFIX}/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-${DISTRIBUTION}"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is ${BUNDLEVERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    less maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo "Nexus timestamp is ${TIMESTAMP}"
    BUNDLEFOLDER="distribution-${DISTRIBUTION}-${BUNDLEVERSION}"
    BUNDLE="distribution-${DISTRIBUTION}-${TIMESTAMP}.zip"
    BUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
else
    BUNDLE="${BUNDLEURL##*/}"
    BUNDLEVERSION="$(basename $(dirname $BUNDLEURL))"
    BUNDLEFOLDER="distribution-${DISTRIBUTION}-${BUNDLEVERSION}"
fi

echo "Distribution bundle URL is ${BUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution folder is ${BUNDLEFOLDER}"


# write the BUNDLE values into a HERE doc to later
#  export to jenkins

cat > ${WORKSPACE}/bundle_vars.txt <<EOF
CONTROLLERFEAT=${CONTROLLERFEAT}
CONTROLLERMEM=${CONTROLLERMEM}
DISTRIBUTION=${DISTRIBUTION}
TIMESTAMP=${TIMESTAMP}
NEXUSURL_PREFIX=${NEXUSURL_PREFIX}
NEXUSPATH=${NEXUSPATH}
BUNDLEVERSION=${BUNDLEVERSION}
BUNDLEFOLDER=${BUNDLEFOLDER}
BUNDLE=${BUNDLE}
ACTUALBUNDLEURL=${BUNDLEURL}
EOF
set +x
ls
echo "#################################################"
echo "## include-raw-integration-get-bundle_vars.txt ##"
echo "#################################################"


