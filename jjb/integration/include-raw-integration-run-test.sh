echo "###########################################"
echo "##  include-raw-integration-run-test.sh  ##"
echo "###########################################"
# Expects $BUNDLEFOLDER to be set earlier in Jenkins job.

  if [ -z ${BUNDLEFOLDER} ] || [ -f ${BUNDLEFOLDER} ]; then
    echo "Location of ODL BUNDLEFOLDER:$BUNDLEFOLDER is not defined"
    exit 1
  fi


# Creates a script to run controller inside a dynamic jenkins slave

cat > ${WORKSPACE}/run-controller-script.sh <<EOF
echo "Downloading the distribution from ${BUNDLEURL}"
cd /tmp
echo "Starting controller for second run..."
./start &

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
   
   scp ${WORKSPACE}/run-controller-script.sh ${CONTROLLER}i:/tmp
   ssh ${CONTROLLER}i 'bash /tmp/run-controller-script.sh'
   
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
