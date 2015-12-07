echo "#################################################"
echo "##       Install Distribution in Cluster       ##"
echo "#################################################"

CONTROLLERMEM="2048m"

find / -name alternatives
echo $PATH
java -version
if [ ${JDKVERSION} == 'openjdk8' ]; then
    echo "Setting the JDK Version to 8"
    alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
else
    echo "Setting the JDK Version to 7"
    alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
fi

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
else
    ACTUALFEATURES="${CONTROLLERFEATURES}"
fi

cat > ${WORKSPACE}/deploy-controller-script.sh <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution from ${ACTUALBUNDLEURL}"
wget --no-verbose  '${ACTUALBUNDLEURL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" \${FEATURESCONF}
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" \${FEATURESCONF}
cat \${FEATURESCONF}

echo "Configuring the log..."
LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' \${LOGCONF}
# FIXME: Make log size limit configurable from build parameter.
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=100GB/g' \${LOGCONF}
cat \${LOGCONF}

echo "Configure max memory..."
MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' \${MEMCONF}
cat \${MEMCONF}

echo "Listing all open ports on controller system"
netstat -natu

EOF

for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP 
    echo "Installing distribution in member-${i} with IP address ${!CONTROLLERIP}"
    scp ${WORKSPACE}/deploy-controller-script.sh ${!CONTROLLERIP}:/tmp
    ssh ${!CONTROLLERIP} 'bash /tmp/deploy-controller-script.sh'
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

