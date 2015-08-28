echo "#################################################"
echo "##       Install Distribution in Cluster       ##"
echo "#################################################"

CONTROLLERMEM="2048m"

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
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' \${LOGCONF}
cat \${LOGCONF}

echo "Configure max memory..."
MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' \${MEMCONF}
cat \${MEMCONF}

EOF

CONTROLLERIPS=(${CONTROLLER0} ${CONTROLLER1} ${CONTROLLER2})
for i in "${!CONTROLLERIPS[@]}"
do
    echo "Installing distribution in member-$((i+1)) with IP address ${CONTROLLERIPS[$i]}"
    scp ${WORKSPACE}/deploy-controller-script.sh ${CONTROLLERIPS[$i]}:/tmp
    ssh ${CONTROLLERIPS[$i]} 'bash /tmp/deploy-controller-script.sh'
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

