CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

echo "Kill any controller running"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Clean workspace"
rm -rf *

echo "Downloading the distribution..."
wget --progress=dot:mega  ${ACTUALBUNDLEURL}

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=${WORKSPACE}/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
sed -ie "s/\(featuresBoot=\|featuresBoot =\)/featuresBoot = ${ACTUALFEATURES},/g" ${FEATURESCONF}
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
netstat -pnatu

if [ ${JDKVERSION} == 'openjdk8' ]; then
    echo "Setting the JRE Version to 8"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.60-2.b27.el7_1.x86_64/jre/bin/java
    export JAVA_HOME=/usr/lib/jvm/java-1.8.0
elif [ ${JDKVERSION} == 'openjdk7' ]; then
    echo "Setting the JRE Version to 7"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.85-2.6.1.2.el7_1.x86_64/jre/bin/java
    export JAVA_HOME=/usr/lib/jvm/java-1.7.0
fi
readlink -e "${JAVA_HOME}/bin/java"
echo "Default JDK Version, JAVA_HOME should override"
java -version

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"

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
        netstat -pnatu
        exit 1
    else
        COUNT=$(( ${COUNT} + 5 ))
        sleep 5
        echo waiting ${COUNT} secs...
    fi
done

echo "loading many features at once.  Need to allow time for problems to show up in logs.  cool down for 5 min ..."
sleep 300

echo "Checking OSGi bundles..."
# sshpass seems to fail with new karaf version
# sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system"
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"$1\" in karaf.log file"
    if grep --quiet "$1" ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log; then
        echo ABORTING: found "$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K  ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K  ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log
        cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log .
        cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log .
        exit 1
    fi

    echo "looking for \"$1\" in karaf_console.log file"
    if grep --quiet "$1" ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log; then
        echo ABORTING: found "$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K  ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K  ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log
        cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log .
        cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log .
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

echo "Fetching Karaf logs"
# TODO: Move instead of copy? Gzip?
cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log .
cp ${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log .

echo "Kill controller"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Detecting misplaced config files"
pushd "${WORKSPACE}/${BUNDLEFOLDER}"
XMLS_FOUND=`echo *.xml`
popd
if [ "$XMLS_FOUND" != "*.xml" ]; then
    echo "Bug 4628 confirmed."
    ## TODO: Uncomment the following when ODL is fixed, to guard against regression.
    # exit 1
else
    echo "Bug 4628 not detected."
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :
