#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

echo "#################################################"
echo "##         Verify Cluster is UP                ##"
echo "#################################################"

cat > ${WORKSPACE}/verify-cluster-is-up.sh <<EOF

CONTROLLERID="member-\$1"
ODL_SYSTEM_IP_PATH=\$2

echo "Waiting for controller to come up..."
COUNT="0"
while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    SHARD="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/jolokia/read/org.opendaylight.controller:Category=Shards,name=\$CONTROLLERID-shard-inventory-config,type=DistributedConfigDatastore)"
    echo \$SHARD
    if ([[ \$RESP == *"200"* ]] && [[ \$SHARD  == *'"status":200'* ]]); then
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

echo "Listing all open ports on controller system.."
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"; then
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

for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Verifying member-${i} with IP address ${!CONTROLLERIP} is UP"
    scp ${WORKSPACE}/verify-cluster-is-up.sh ${!CONTROLLERIP}:/tmp
    ssh ${!CONTROLLERIP} "bash /tmp/verify-cluster-is-up.sh ${i} ${!CONTROLLERIP}"
done

if [ ${NUM_OPENSTACK_SYSTEM} -gt 0 ]; then
   echo "Exiting without running tests to deploy openstack for testing"
   exit
fi

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    COOLDOWN_PERIOD="180"
else
    COOLDOWN_PERIOD="60"
fi
echo "Cool down for ${COOLDOWN_PERIOD} seconds :)..."
sleep ${COOLDOWN_PERIOD}

echo "Generating controller variables..."
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    odl_variables=${odl_variables}" -v ${CONTROLLERIP}:${!CONTROLLERIP}"
    echo "Lets's take the karaf thread dump"
    KARAF_PID=$(ssh ${!CONTROLLERIP} "ps aux | grep 'distribution-karaf' | grep -v grep | tr -s ' ' | cut -f2 -d' '")
    ssh ${!CONTROLLERIP} "jstack $KARAF_PID"> ${WORKSPACE}/karaf_${i}_threads_before.log || true
done

echo "Generating tools IP variables..."
for i in `seq 1 ${NUM_TOOLS_SYSTEM}`
do
    MININETIP="TOOLS_SYSTEM_${i}_IP"
    tools_variables="${tools_variables} -v ${MININETIP}:${!MININETIP}"
done

echo "Locating test plan to use..."
testplan_filepath="${WORKSPACE}/test/csit/testplans/${STREAMTESTPLAN}"
if [ ! -f "${testplan_filepath}" ]; then
    testplan_filepath="${WORKSPACE}/test/csit/testplans/${TESTPLAN}"
fi

echo "Changing the testplan path..."
cat "${testplan_filepath}" | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`

echo "Starting Robot test suites ${SUITES} ..."
pybot \
-N ${TESTPLAN} \
--removekeywords wuks \
-c critical \
-e exclude \
-v BUNDLE_URL:${ACTUALBUNDLEURL} \
-v BUNDLEFOLDER:${BUNDLEFOLDER} \
-v CONTROLLER:${ODL_SYSTEM_1_IP} \
-v CONTROLLER1:${ODL_SYSTEM_2_IP} \
-v CONTROLLER2:${ODL_SYSTEM_3_IP} \
-v CONTROLLER_USER:${USER} \
-v JAVA_HOME:${JAVA_HOME} \
-v JDKVERSION:${JDKVERSION} \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
-v MININET:${TOOLS_SYSTEM_1_IP} \
-v MININET1:${TOOLS_SYSTEM_2_IP} \
-v MININET2:${TOOLS_SYSTEM_3_IP} \
-v MININET_USER:${USER} \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
-v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
-v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
-v ODL_STREAM:${DISTROSTREAM} \
-v ODL_SYSTEM_IP:${ODL_SYSTEM_1_IP} \
${odl_variables} \
-v ODL_SYSTEM_PASSWORD: \
-v ODL_SYSTEM_PROMPT:\> \
-v ODL_SYSTEM_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_1_IP} \
${tools_variables} \
-v TOOLS_SYSTEM_PASSWORD: \
-v TOOLS_SYSTEM_PROMPT:\> \
-v TOOLS_SYSTEM_USER:${USER} \
-v USER_HOME:${HOME} \
-v WORKSPACE:/tmp \
${TESTOPTIONS} \
${SUITES} || true

echo "Examining the files in data/log and checking filesize"
ssh ${ODL_SYSTEM_1_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_1_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"
ssh ${ODL_SYSTEM_2_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_2_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"
ssh ${ODL_SYSTEM_3_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_3_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

set +e  # We do not want to create red dot just because something went wrong while fetching logs.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Lets's take the karaf thread dump again"
    KARAF_PID=$(ssh ${!CONTROLLERIP} "ps aux | grep 'distribution-karaf' | grep -v grep | tr -s ' ' | cut -f2 -d' '")
    ssh ${!CONTROLLERIP} "jstack $KARAF_PID"> ${WORKSPACE}/karaf_${i}_threads_after.log || true
    echo "killing karaf process..."
    ssh "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done
sleep 5
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Compressing karaf.log ${i}"
    ssh ${!CONTROLLERIP} gzip --best /tmp/${BUNDLEFOLDER}/data/log/karaf.log
    echo "Fetching compressed karaf.log ${i}"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz" "odl${i}_karaf.log.gz"
    # TODO: Gzip also these?
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log" "odl${i}_karaf_console.log"
done
true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :
