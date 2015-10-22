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
        echo "Dumping Karaf log..."
        cat /tmp/${BUNDLEFOLDER}/data/log/karaf.log
        echo "Listing all open ports on controller system"
        netstat -natu
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo "Checking OSGi bundles..."
sshpass -p karaf /tmp/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system"
netstat -natu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" /tmp/${BUNDLEFOLDER}/data/log/karaf.log; then
        echo ABORTING: found "\$1"
        echo "Dumping Karaf log..."
        cat /tmp/${BUNDLEFOLDER}/data/log/karaf.log
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

EOF

ODL_SYSTEM_IPS=(${ODL_SYSTEM_1_IP} ${ODL_SYSTEM_2_IP} ${ODL_SYSTEM_3_IP})
for i in "${!ODL_SYSTEM_IPS[@]}"
do
    echo "Verifying member-$((i+1)) with IP address ${ODL_SYSTEM_IPS[$i]} is UP"
    scp ${WORKSPACE}/verify-cluster-is-up.sh ${ODL_SYSTEM_IPS[$i]}:/tmp
    ssh ${ODL_SYSTEM_IPS[$i]} "bash /tmp/verify-cluster-is-up.sh $((i+1)) ${ODL_SYSTEM_IPS[$i]}"
done

echo "Cool down for 1 min :)..."
sleep 60

echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v CONTROLLER:${ODL_SYSTEM_IP} -v CONTROLLER1:${ODL_SYSTEM_2_IP} \
-v CONTROLLER2:${ODL_SYSTEM_3_IP} -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} -v ODL_SYSTEM_2_IP:${ODL_SYSTEM_2_IP} \
-v ODL_SYSTEM_3_IP:${ODL_SYSTEM_3_IP} -v CONTROLLER_USER:${USER} -v ODL_SYSTEM_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
-v TOOLS_SYSTEM_USER:${USER} \
-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} -v MININET_USER:${USER} \
-v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Fetching Karaf log"
scp $ODL_SYSTEM_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller0-karaf.log
scp $ODL_SYSTEM_2_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller1-karaf.log
scp $ODL_SYSTEM_3_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller2-karaf.log

# vim: ts=4 sw=4 sts=4 et ft=sh :

