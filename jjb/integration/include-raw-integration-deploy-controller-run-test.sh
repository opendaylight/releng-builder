#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

CONTROLLERMEM="2048m"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
else
    ACTUALFEATURES="${CONTROLLERFEATURES}"
fi

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

cat > ${WORKSPACE}/controller-script.sh <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution..."
wget --no-verbose '${ACTUALBUNDLEURL}'

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

echo "Listing all open ports on controller system..."
netstat -natu

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
        echo "Dumping Karaf log..."
        head --bytes=1M "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Listing all open ports on controller system"
        netstat -natu
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo "Cool down for 1 min :)..."
sleep 60

echo "Checking OSGi bundles..."
sshpass -p karaf /tmp/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system..."
netstat -natu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" /tmp/${BUNDLEFOLDER}/data/log/karaf.log; then
        echo ABORTING: found "\$1"
        echo "Dumping Karaf log..."
        head --bytes=1M "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

EOF

scp ${WORKSPACE}/controller-script.sh ${ODL_SYSTEM_IP}:/tmp
ssh ${ODL_SYSTEM_IP} 'bash /tmp/controller-script.sh'

echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
-v CONTROLLER:${ODL_SYSTEM_IP} -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} -v CONTROLLER_USER:${USER} -v ODL_SYSTEM_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
-v TOOLS_SYSTEM_USER:${USER} \
-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} -v MININET_USER:${USER} \
-v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Killing ODL and fetching Karaf log..."
set +e  # We do not want to create red dot just because something went wrong while fetching logs.
ssh "${ODL_SYSTEM_IP}" head --bytes=1M "/tmp/${BUNDLEFOLDER}/data/log/karaf.log" > "karaf.log"
ssh "${ODL_SYSTEM_IP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
sleep 5
ssh "${ODL_SYSTEM_IP}" xz -9ekvv "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
scp "${ODL_SYSTEM_IP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.xz" .
true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :

