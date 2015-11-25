CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

echo "Kill any controller running"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Clean workspace"
rm -rf *

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
sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' ${LOGCONF}
# FIXME: Make log size limit configurable from build parameter.
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=100GB/g' ${LOGCONF}
cat ${LOGCONF}

echo "Configure the repos..."
REPOCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.url.mvn.cfg
sed -ie '/http/d' ${REPOCONF}
sed -ie '$s/...$//' ${REPOCONF}
cat ${REPOCONF}

echo "Configure max memory..."
MEMCONF=${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv
sed -ie "s/2048m/${CONTROLLERMEM}/g" ${MEMCONF}
cat ${MEMCONF}

echo "Starting controller..."
${WORKSPACE}/${BUNDLEFOLDER}/bin/start

echo "sleeping for 10 seconds..."
sleep 10

echo "Installing all features..."
sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf "feature:install ${ACTUALFEATURES}" || echo $? > ${WORKSPACE}/error.txt

echo "Killing controller."
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Compressing and fetching Karaf log..."
xz -9ekvv "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
mv "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log.xz" .
head --bytes=1M "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" > "karaf.log"
# TODO: Do we want different name for karaf.log chunk to signal it may be not complete?

echo "Exit with error"
if [ -f ${WORKSPACE}/error.txt ]; then
    echo "Failed to deploy offline"
    exit 1
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :

