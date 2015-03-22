# Create a script to run controller inside a dynamic jenkins slave
DISTRIBUTION="karaf"
CONTROLLERFEATURES="odl-integration-compatible-with-all"
CONTROLLERMEM="3072m"

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-${DISTRIBUTION}"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is $BUNDLEVERSION"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo "Nexus timestamp is $TIMESTAMP"
    BUNDLEFOLDER="distribution-${DISTRIBUTION}-${BUNDLEVERSION}"
    BUNDLE="distribution-${DISTRIBUTION}-${TIMESTAMP}.zip"
    BUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
else
    BUNDLE="$(echo ${BUNDLEURL} | awk -F '/' '{ print $(NF) }')"
    echo "Finding out Bundle folder..."
    wget --no-verbose  ${BUNDLEURL}
    BUNDLEFOLDER="$(unzip -qql ${BUNDLE} | head -n1 | tr -s ' ' | cut -d' ' -f5- | rev | cut -c 2- | rev)"
    rm ${BUNDLE}
fi

echo "Distribution bundle URL is ${BUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution folder is ${BUNDLEFOLDER}"

echo "Downloading the distribution from ${BUNDLEURL}"
wget --no-verbose  ${BUNDLEURL}

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
cd ${BUNDLEFOLDER}/etc
CFG=org.apache.karaf.features.cfg
cp ${CFG} ${CFG}.bak
cat ${CFG}.bak | sed "s/^featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${CONTROLLERFEATURES}/" > ${CFG}.1
cat ${CFG}.1 | sed "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%" > ${CFG}
cat ${CFG}

echo "Configuring the log..."
LOG=org.ops4j.pax.logging.cfg
cp ${LOG} ${LOG}.bak
cat ${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > ${LOG}
cat ${LOG}

echo "Configure the repos..."
REPO=org.ops4j.pax.url.mvn.cfg
cp ${REPO} ${REPO}.bak
cat ${REPO}.bak | sed '/http/d' | sed '$s/...$//'> ${REPO}
cat ${REPO}

echo "Configure max memory..."
MEM=setenv
cd ../bin
cp ${MEM} ${MEM}.bak
cat ${MEM}.bak | sed 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/' > ${MEM}
cat ${MEM}

echo "Starting controller..."
./start &

echo "sleeping for 20 seconds..."
sleep 20

echo "Check OSGi bundles..."
./client "feature:install ${CONTROLLERFEATURES}" || echo $? > ${WORKSPACE}/error.txt

echo "Fetching Karaf log"
cd ${WORKSPACE}
cp ${BUNDLEFOLDER}/data/log/karaf.log .

echo "Exit with error"
if [ `cat error.txt` -ne 0 ]; then
    echo "Failed to deploy offline"
    exit 1
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :

