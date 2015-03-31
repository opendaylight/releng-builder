echo "###########################################"
echo "##  include-raw-integration-run-test.sh  ##"
echo "###########################################"
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

cat > ${WORKSPACE}/run-test-controller-script.sh <<EOF
set -x
cd /tmp
cd ${BUNDLEFOLDER}
echo "BUNDLE: $BUNDLEFOLDER"
echo "Checking status of controller..."
    bash bin/status & 
    bash bin/start &
echo "Waiting for controller to come up..."
COUNT="0"
while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [[ \$RESP == *"200"* ]]; then
        echo Controller is UP
    SHARD="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n"\
http://localhost:8181/jolokia/read/org.opendaylight.controller:Category=Shards,name=member-0-shard-inventory-config,type=DistributedConfigDatastore)"
      echo \$SHARD
      if [[ \$SHARD  == *'"status":200'* ]]
       then
        break
      fi  
      break

    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo "A moments reflection :)..."
sleep 60

echo "Checking OSGi bundles..."
./client 'bundle:list'
set +x
EOF


for  i in "${!CONTROLLERIPS[@]}"
do
   echo "Running tests on ${CONTROLLERIPS[$i]} which is node $i "
   
   scp ${WORKSPACE}/run-test-controller-script.sh ${CONTROLLERIPS[$i]}:/tmp
   ssh ${CONTROLLERIPS[$i]} "bash /tmp/run-test-controller-script.sh $i"
   
set +x   

done



echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude --loglevel TRACE -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp -v CONTROLLER:${CONTROLLER0} -v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES}
#
echo "Fetching Karaf log"
scp $CONTROLLER0:/tmp/$BUNDLEFOLDER/data/log/karaf.log .
cat karaf.log 
#
## vim: ts=4 sw=4 sts=4 et ft=sh :
echo "##############################################"
echo "## END include-raw-integration-run-test.sh  ##"
echo "##############################################"
