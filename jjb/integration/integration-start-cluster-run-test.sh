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

CONTROLLERIPS=(${CONTROLLER0} ${CONTROLLER1} ${CONTROLLER2})
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
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v CONTROLLER:${CONTROLLER0} -v CONTROLLER1:${CONTROLLER1} -v CONTROLLER2:${CONTROLLER2} \
-v CONTROLLER_USER:${USER} -v MININET:${MININET0} -v MININET1:${MININET1} -v MININET2:${MININET2} \
-v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Fetching Karaf log"
scp $CONTROLLER0:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller0-karaf.log
scp $CONTROLLER1:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller1-karaf.log
scp $CONTROLLER2:/tmp/$BUNDLEFOLDER/data/log/karaf.log controller2-karaf.log

# vim: ts=4 sw=4 sts=4 et ft=sh :

