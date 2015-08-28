NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}
CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="${NEXUSURL_PREFIX}/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-karaf"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is ${BUNDLEVERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
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

echo "Downloading the distribution..."
wget --no-verbose  ${ACTUALBUNDLEURL}

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" ${FEATURESCONF}
cat ${FEATURESCONF}

echo "Configuring the log..."
LOGCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' ${LOGCONF}
cat ${LOGCONF}

echo "Configure the repos..."
REPOCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.url.mvn.cfg
sed -ie '/http/d' ${REPOCONF}
sed -ie '$s/...$//' ${REPOCONF}
cat ${REPOCONF}

echo "Configure max memory..."
MEMCONF=${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' ${MEMCONF}
cat ${MEMCONF}

echo "Starting controller..."
${WORKSPACE}/${BUNDLEFOLDER}/bin/start

echo "sleeping for 10 seconds..."
sleep 10

echo "Check OSGi bundles..."
sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf "feature:install ${ACTUALFEATURES}" || echo $? > ${WORKSPACE}/error.txt

echo "Fetching Karaf log"
cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log .

echo "Exit with error"
if [ `cat error.txt` -ne 0 ]; then
    echo "Failed to deploy offline"
    exit 1
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :

