CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

echo "Kill any controller running"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Clean workspace"
rm -rf *

echo "Downloading the distribution..."
wget --progress=dot:mega  "${ACTUAL_BUNDLE_URL}"

echo "Extracting the new controller..."
unzip -q "${BUNDLE}"

echo "Configuring the startup features..."
FEATURESCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg"
FEATURE_TEST_STRING="features-integration-test"
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    FEATURE_TEST_STRING="features-test"
fi

sed -ie "s%\(featuresRepositories=\|featuresRepositories =\)%featuresRepositories = mvn:org.opendaylight.integration/${FEATURE_TEST_STRING}/${BUNDLEVERSION}/xml/features,%g" ${FEATURESCONF}

# Add actual boot features.
sed -ie "s/\(featuresBoot=\|featuresBoot =\)/featuresBoot = ${ACTUALFEATURES},/g" "${FEATURESCONF}"
cat "${FEATURESCONF}"

echo "Configuring the log..."
LOGCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg"
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' "${LOGCONF}"
cat "${LOGCONF}"

echo "Configure max memory..."
MEMCONF="${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv"
sed -ie "s/2048m/${CONTROLLERMEM}/g" "${MEMCONF}"
cat "${MEMCONF}"

echo "Listing all open ports on controller system"
netstat -pnatu

if [ "${JDKVERSION}" == 'openjdk8' ]; then
    echo "Setting the JRE Version to 8"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.60-2.b27.el7_1.x86_64/jre/bin/java
    export JAVA_HOME='/usr/lib/jvm/java-1.8.0'
elif [ "${JDKVERSION}" == 'openjdk7' ]; then
    echo "Setting the JRE Version to 7"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.85-2.6.1.2.el7_1.x86_64/jre/bin/java
    export JAVA_HOME='/usr/lib/jvm/java-1.7.0'
fi
readlink -e "${JAVA_HOME}/bin/java"
echo "Default JDK Version, JAVA_HOME should override"
java -version

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p ${WORKSPACE}/${BUNDLEFOLDER}/data/log

echo "Starting controller..."
${WORKSPACE}/${BUNDLEFOLDER}/bin/start

if [ "${DISTROSTREAM}" == "carbon" ] || [ "${DISTROSTREAM}" == "nitrogen" ];
then
    echo "only oxygen and above have the infrautils.ready feature, so using REST API to /modules or /shards to determine if the controller is ready.";

    COUNT="0"

    while true; do
        RESP="$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
        echo ${RESP}

        if [[ ${RESP} == *"200"* ]]; then
            echo "Controller is UP"
            break

        elif (( "${COUNT}" > "600" )); then
            echo Timeout Controller DOWN
            echo "Dumping first 500K bytes of karaf log..."
            head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
            echo "Dumping last 500K bytes of karaf log..."
            tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
            echo "Listing all open ports on controller system"
            netstat -pnatu
            exit 1
        else

        COUNT=$(( ${COUNT} + 1 ))
        sleep 1

        if [[ $((${COUNT} % 5)) == 0 ]]; then
            echo already waited ${COUNT} seconds...
        fi
    fi
    done

else
    echo "Waiting up to 3 minutes for controller to come up, checking every 5 seconds..."
    for i in {1..36};
        do sleep 5;
        grep 'org.opendaylight.infrautils.ready-impl.*System ready' /tmp/${BUNDLEFOLDER}/data/log/karaf.log
        if [ $? -eq 0 ]
        then
          echo "Controller is UP"
          break
        fi
    done;

    # if we ended up not finding ready status in the above loop, we can output some debugs
    grep 'org.opendaylight.infrautils.ready-impl.*System ready' /tmp/${BUNDLEFOLDER}/data/log/karaf.log
    if [ $? -ne 0 ]
    then
        echo "Timeout Controller DOWN"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Listing all open ports on controller system"
        netstat -pnatu
        exit 1
    fi
fi

echo "Checking OSGi bundles..."
# sshpass seems to fail with new karaf version
# sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system"
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"$1\" in karaf.log file"
    if grep --quiet "$1" "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"; then
        echo ABORTING: found "$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
        cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
        cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .
        exit 1
    fi

    echo "looking for \"$1\" in karaf_console.log file"
    if grep --quiet "$1" "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"; then
        echo ABORTING: found "$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"
        cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
        cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

echo "Fetching Karaf logs"
# TODO: Move instead of copy? Gzip?
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .

echo "Kill controller"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Bug 4628: Detecting misplaced config files"
pushd "${WORKSPACE}/${BUNDLEFOLDER}" || exit
XMLS_FOUND=`echo *.xml`
popd || exit
if [ "$XMLS_FOUND" != "*.xml" ]; then
    echo "Bug 4628 confirmed."
    ## TODO: Uncomment the following when ODL is fixed, to guard against regression.
    # exit 1
else
    echo "Bug 4628 not detected."
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :
