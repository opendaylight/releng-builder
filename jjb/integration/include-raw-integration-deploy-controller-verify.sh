CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

if [ ${JDKVERSION} == 'openjdk8' ]; then
    echo "Setting the JDK Version to 8"
    update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
else
    echo "Setting the JDK Version to 7"
    update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
fi

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
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" ${FEATURESCONF}
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" ${FEATURESCONF}
cat ${FEATURESCONF}

echo "Configuring the log..."
LOGCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' ${LOGCONF}
cat ${LOGCONF}

echo "Configure max memory..."
MEMCONF=${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv
sed -ie "s/2048m/${CONTROLLERMEM}/g" ${MEMCONF}
cat ${MEMCONF}

echo "Listing all open ports on controller system"
netstat -natu

echo "Starting controller..."
${WORKSPACE}/${BUNDLEFOLDER}/bin/start

echo "Waiting for controller to come up..."
COUNT=0
while true; do
    RESP="$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null || true )"
    echo ${RESP}
    if [[ ${RESP} == *"200"* ]]; then
        echo Controller is UP
        break
    elif (( ${COUNT} > 600 )); then
        echo Timeout Controller DOWN
        echo "Dumping Karaf log..."
        cat ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log
        echo "Listing all open ports on controller system"
        netstat -natu
        exit 1
    else
        COUNT=$(( ${COUNT} + 5 ))
        sleep 5
        echo waiting ${COUNT} secs...
    fi
done

echo "Checking OSGi bundles..."
sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system"
netstat -natu

function exit_on_log_file_message {
    echo "looking for \"$1\" in log file"
    if grep --quiet "$1" ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log; then
        echo ABORTING: found "$1"
        echo "Dumping Karaf log..."
        cat ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

echo "Fetching Karaf log"
cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log .

echo "Kill controller"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

# vim: ts=4 sw=4 sts=4 et ft=sh :

