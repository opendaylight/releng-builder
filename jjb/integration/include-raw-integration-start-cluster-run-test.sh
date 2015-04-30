echo "#########################################################"
echo "##  include-raw-integration-start-cluster-run-test.sh  ##"
echo "#########################################################"
# Expects $BUNDLEFOLDER to be set earlier in Jenkins job.
set -x

  if [ -z ${BUNDLEFOLDER} ] || [ -f ${BUNDLEFOLDER} ]; then
    echo "Location of ODL BUNDLEFOLDER:$BUNDLEFOLDER is not defined"
    exit 1
  fi

# populate $(CONTROLLERIPS)

  declare CONTROLLERIPS=($(cat slave_addresses.txt | grep CONTROLLER | awk -F = '{print $2}'))
  declare -p CONTROLLERIPS

# Creates a script to run controller inside a dynamic jenkins slave

cat > ${WORKSPACE}/run-startandtest-controller-script.sh <<EOF
set -x
cd /tmp
cd ${BUNDLEFOLDER}
echo "BUNDLE: $BUNDLEFOLDER"
echo "Checking status of controller..."
    bash bin/status
    bash bin/start &
set +x
EOF



cat > ${WORKSPACE}/run-verify-controller-isup-script.sh <<EOF
set -x
cd /tmp
cd ${BUNDLEFOLDER}
echo "BUNDLE: $BUNDLEFOLDER"
echo "Checking status of controller..."
 bash bin/status
 echo "Waiting for controller to come up..."
 COUNT="0"


while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [[ \$RESP == *"200"* ]]; then
        echo Controller is UP
    SHARD="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/jolokia/read/org.opendaylight.controller:Category=Shards,name=member-0-shard-inventory-config,type=DistributedConfigDatastore)"
      echo \$SHARD
      if [[ \$SHARD  == *'"status":200'* ]]
       then
        break
      fi
      break

    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN
        echo "Dumping Karaf log..."
        ls
        pwd
        cd data/log
        cat karaf.log
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

cd /tmp/${BUNDLEFOLDER}/bin/

echo "Checking OSGi bundles..."
sshpass -p karaf ./client -u karaf 'bundle:list'

EOF


for  i in "${!CONTROLLERIPS[@]}"
do
 echo "Copying HERE docs to ${CONTROLLERIPS[$i]} which is node $i "
 scp ${WORKSPACE}/run-startandtest-controller-script.sh \
${CONTROLLERIPS[$i]}:/tmp

 scp ${WORKSPACE}/run-verify-controller-isup-script.sh \
${CONTROLLERIPS[$i]}:/tmp
done

for  i in "${!CONTROLLERIPS[@]}"
do
 echo "Starting ${CONTROLLERIPS[$i]} on node $i "
 ssh ${CONTROLLERIPS[$i]} "bash /tmp/run-startandtest-controller-script.sh $i"&
done

for  i in "${!CONTROLLERIPS[@]}"
do
 echo "Running sanity tests on ${CONTROLLERIPS[$i]} on node $i "
 ssh ${CONTROLLERIPS[$i]} "bash /tmp/run-verify-controller-isup-script.sh $i"
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
-v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES}


#
echo "######  Fetching controller0-karaf.log ############"
scp $CONTROLLER0:/tmp/$BUNDLEFOLDER/data/log/karaf.log \
controller0-karaf.log
# cat karaf.log
#
echo "######  Fetching controller1-karaf.log ############"
scp $CONTROLLER1:/tmp/$BUNDLEFOLDER/data/log/karaf.log \
controller1-karaf.log
# cat controller1-karaf.log

echo "######  Fetching controller2-karaf.log ############"
scp $CONTROLLER2:/tmp/$BUNDLEFOLDER/data/log/karaf.log \
controller2-karaf.log
# cat controller2-karaf.log

## vim: ts=4 sw=4 sts=4 et ft=sh :
echo "############################################################"
echo "## END include-raw-integration-start-cluster-run-test.sh  ##"
echo "############################################################"
