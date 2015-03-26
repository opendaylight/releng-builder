echo "###########################################"
echo "##  include-raw-integration-run-test.sh  ##"
echo "###########################################"
# Expects $BUNDLEFOLDER to be set earlier in Jenkins job.

  if [ -z ${BUNDLEFOLDER} ] || [ -f ${BUNDLEFOLDER} ]; then
    echo "Location of ODL BUNDLEFOLDER:$BUNDLEFOLDER is not defined"
    exit 1
  fi


# Creates a script to run controller inside a dynamic jenkins slave

cat > ${WORKSPACE}/run-test-controller-script.sh <<EOF


cd /tmp
echo "Checking status of controller..."
    cd./status &

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

echo "Cool down for 1 min :)..."
sleep 60

echo "Checking OSGi bundles..."
./client 'bundle:list'

EOF

set -x
for  i in "${!CONTROLLERIPS[@]}"
do
   echo "IP address of node is: $i and index is   ${CONTROLLERIPS[$i]}"
   
   scp ${WORKSPACE}/run-test-controller-script.sh ${CONTROLLER}$i:/tmp
   ssh ${CONTROLLER}$i "bash /tmp/run-test-controller-script.sh $i"
   
set +x   

done



echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude --loglevel TRACE -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp -v CONTROLLER:${CONTROLLER0} -v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES}
#
#echo "Fetching Karaf log"
#scp $CONTROLLER0:/tmp/$BUNDLEFOLDER/data/log/karaf.log .
#
## vim: ts=4 sw=4 sts=4 et ft=sh :
echo "##############################################"
echo "## END include-raw-integration-run-test.sh  ##"
echo "##############################################"
