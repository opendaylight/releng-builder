#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

CONTROLLERMEM="2048m"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
    COOLDOWN_PERIOD="180"
else
    ACTUALFEATURES="${CONTROLLERFEATURES}"
    COOLDOWN_PERIOD="60"
fi
# Some versions of jenkins job builder result in feature list containing spaces
# and ending in newline. Remove all that.
ACTUALFEATURES=`echo "${ACTUALFEATURES}" | tr -d '\n \r'`

if [ -f ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} ]; then
    echo "scriptplan exists!!!"
    echo "Changing the scriptplan path..."
    cat ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > scriptplan.txt
    cat scriptplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' scriptplan.txt ); do
        echo "Executing ${line}..."
        source ${line}
    done
fi

cat > ${WORKSPACE}/configuration-script.sh <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution..."
wget --progress=dot:mega '${ACTUALBUNDLEURL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
CUSTOMPROP=/tmp/${BUNDLEFOLDER}/etc/custom.properties
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" \${FEATURESCONF}
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features,mvn:org.apache.karaf.decanter/apache-karaf-decanter/1.0.0/xml/features%g" \${FEATURESCONF}
cat \${FEATURESCONF}

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
  echo "ovsdb.l3.fwd.enabled=yes" >> \${CUSTOMPROP}
fi
cat \${CUSTOMPROP}

echo "Configuring the log..."
LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' \${LOGCONF}
# FIXME: Make log size limit configurable from build parameter.
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=30GB/g' \${LOGCONF}
cat \${LOGCONF}

echo "Configure java home and max memory..."
MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
sed -ie 's%^# export JAVA_HOME%export JAVA_HOME="\${JAVA_HOME:-${JAVA_HOME}}"%g' \${MEMCONF}
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' \${MEMCONF}
cat \${MEMCONF}

echo "Listing all open ports on controller system..."
netstat -pnatu

echo "Set Java version"
sudo /usr/sbin/alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
sudo /usr/sbin/alternatives --set java ${JAVA_HOME}/bin/java
echo "JDK default version ..."
java -version

echo "Set JAVA_HOME"
export JAVA_HOME="$JAVA_HOME"
# Did you know that in HERE documents, single quote is an ordinary character, but backticks are still executing?
JAVA_RESOLVED=\`readlink -e "\${JAVA_HOME}/bin/java"\`
echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"

EOF

# Create the startup script to be run on controller.
cat > ${WORKSPACE}/startup-script.sh <<EOF

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

echo "Waiting for controller to come up..."
COUNT="0"
while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [[ \$RESP == *"200"* ]]; then
        echo Controller is UP
        break
    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Listing all open ports on controller system"
        netstat -pnatu
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo "Cool down for ${COOLDOWN_PERIOD} seconds :)..."
sleep ${COOLDOWN_PERIOD}

echo "Listing all open ports on controller system..."
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" /tmp/${BUNDLEFOLDER}/data/log/karaf.log; then
        echo ABORTING: found "\$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

EOF

# Execute the configuration script on controller.
scp ${WORKSPACE}/configuration-script.sh ${ODL_SYSTEM_IP}:/tmp
ssh ${ODL_SYSTEM_IP} 'bash /tmp/configuration-script.sh'

# Run config plan in case it exists
if [ -f ${WORKSPACE}/test/csit/configplans/${TESTPLAN} ]; then
    echo "configplan exists!!!"
    echo "Reading the configplan:"
    cat ${WORKSPACE}/test/csit/configplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > configplan.txt
    cat configplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' configplan.txt ); do
        echo "Executing ${line}..."
        source ${line}
    done
fi

# Copy over the startup script to controller and execute it.
scp ${WORKSPACE}/startup-script.sh ${ODL_SYSTEM_IP}:/tmp
ssh ${ODL_SYSTEM_IP} 'bash /tmp/startup-script.sh'

if [ ${NUM_OPENSTACK_SYSTEM} -gt 0 ]; then
   echo "Exiting without running tests to deploy openstack for testing"
   exit
fi

echo "Lets's take the karaf thread dump"
KARAF_PID=$(ssh ${ODL_SYSTEM_IP} "ps aux | grep 'distribution-karaf' | grep -v grep | tr -s ' ' | cut -f2 -d' '")
ssh ${ODL_SYSTEM_IP} "jstack $KARAF_PID"> ${WORKSPACE}/karaf_threads_before.log || true

echo "Locating test plan to use..."
testplan_filepath="${WORKSPACE}/test/csit/testplans/${STREAMTESTPLAN}"
if [ ! -f "${testplan_filepath}" ]; then
    testplan_filepath="${WORKSPACE}/test/csit/testplans/${TESTPLAN}"
fi

echo "Changing the testplan path..."
cat "${testplan_filepath}" | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt
SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} --removekeywords wuks -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v JAVA_HOME:${JAVA_HOME} -v BUNDLE_URL:${ACTUALBUNDLEURL} -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
-v CONTROLLER:${ODL_SYSTEM_IP} -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_IP} \
-v CONTROLLER_USER:${USER} -v ODL_SYSTEM_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
-v TOOLS_SYSTEM_4_IP:${TOOLS_SYSTEM_4_IP} -v TOOLS_SYSTEM_5_IP:${TOOLS_SYSTEM_5_IP} -v TOOLS_SYSTEM_6_IP:${TOOLS_SYSTEM_6_IP} \
-v TOOLS_SYSTEM_USER:${USER} -v JDKVERSION:${JDKVERSION} -v ODL_STREAM:${DISTROSTREAM} -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} \
-v MININET3:${TOOLS_SYSTEM_4_IP} -v MININET4:${TOOLS_SYSTEM_5_IP} -v MININET5:${TOOLS_SYSTEM_6_IP} \
-v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true
# FIXME: Sort (at least -v) options alphabetically.

echo "Lets's take the karaf thread dump again"
KARAF_PID=$(ssh ${ODL_SYSTEM_IP} "ps aux | grep 'distribution-karaf' | grep -v grep | tr -s ' ' | cut -f2 -d' '")
ssh ${ODL_SYSTEM_IP} "jstack $KARAF_PID"> ${WORKSPACE}/karaf_threads_after.log || true

echo "Killing ODL"
set +e  # We do not want to create red dot just because something went wrong while fetching logs.
ssh "${ODL_SYSTEM_IP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
sleep 5
echo "Compressing karaf.log"
ssh ${ODL_SYSTEM_IP} gzip --best "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
echo "Fetching compressed karaf.log"
scp "${ODL_SYSTEM_IP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz" .
# TODO: Should we compress the output log file as well?
scp "${ODL_SYSTEM_IP}:/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log" .
true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :
