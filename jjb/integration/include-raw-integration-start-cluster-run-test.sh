echo "#################################################"
echo "##         Verify Cluster is UP                ##"
echo "#################################################"

cat > ${WORKSPACE}/verify-cluster-is-up.sh <<EOF

CONTROLLERID="member-\$1"
CONTROLLERIP=\$2

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
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo "Checking OSGi bundles..."
sshpass -p karaf /tmp/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

EOF

CONTROLLERIPS=(${CONTROLLER_IP} ${CONTROLLER_2_IP} ${CONTROLLER_3_IP})
for i in "${!CONTROLLERIPS[@]}"
do
    echo "Verifying member-$((i+1)) with IP address ${CONTROLLERIPS[$i]} is UP"
    scp ${WORKSPACE}/verify-cluster-is-up.sh ${CONTROLLERIPS[$i]}:/tmp
    ssh ${CONTROLLERIPS[$i]} "bash /tmp/verify-cluster-is-up.sh $((i+1)) ${CONTROLLERIPS[$i]}"
done

echo "Cool down for 1 min :)..."
sleep 60

echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v CONTROLLER:${CONTROLLER_IP} -v CONTROLLER1:${CONTROLLER_2_IP} \
-v CONTROLLER2:${CONTROLLER_3_IP} -v CONTROLLER_IP:${CONTROLLER_IP} -v CONTROLLER_2_IP:${CONTROLLER_2_IP} \
-v CONTROLLER_3_IP:${CONTROLLER_3_IP} -v CONTROLLER_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
-v TOOLS_SYSTEM_USER:${USER} \
-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} -v MININET_USER:${USER} \
-v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Fetching Karaf log"
scp $CONTROLLER_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller0-karaf.log
scp $CONTROLLER_2_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller1-karaf.log
scp $CONTROLLER_3_IP:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller2-karaf.log

# vim: ts=4 sw=4 sts=4 et ft=sh :

