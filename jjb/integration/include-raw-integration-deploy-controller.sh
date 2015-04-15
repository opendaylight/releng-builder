echo "#################################################"
echo "##   include-raw-integration-deploy-controller ##"
echo "#################################################"

set -x


cat > ${WORKSPACE}/deploy-controller-script.sh <<EOF
echo "Downloading the distribution from ${ACTUALBUNDLEURL}"
cd /tmp
wget --no-verbose  ${ACTUALBUNDLEURL}

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
cd ${BUNDLEFOLDER}/etc
echo "BUNDLE: $BUNDLEFOLDER"

CFG=org.apache.karaf.features.cfg
cp \${CFG} \${CFG}.bak
cat \${CFG}.bak | sed "s/^featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${CONTROLLERFEATURES}/" > \${CFG}
cat \${CFG}

echo "Configuring the log..."
LOG=org.ops4j.pax.logging.cfg
cp \${LOG} \${LOG}.bak
cat \${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > \${LOG}
cat \${LOG}

echo "Configure max memory..."
MEM=setenv
cd ../bin
cp \${MEM} \${MEM}.bak
cat \${MEM}.bak | sed 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/' > \${MEM}
cat \${MEM}

echo "Starting deploy controller..."
./start &

EOF

cat > ${WORKSPACE}/deploy-sanitytest-controller-script.sh <<EOF
set -x

echo "Waiting for controller to come up..."
cd /tmp
cd ${BUNDLEFOLDER}/bin

COUNT="0"


while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [[ \$RESP == *"200"* ]]; then
        echo Controller is UP
        break
    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN

        cd /tmp/${BUNDLEFOLDER}/data/
        cat karaf.log
        exit 1
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done


cd /tmp/${BUNDLEFOLDER}/bin/

#echo "Cool down for 1 min :)..."
#sleep 60
echo "Checking OSGi bundles..."
./client 'bundle:list'

./stop &

set +x

EOF


set +x




###############################################################
##  Define a function to run controller-script on controller  #
###############################################################

function runcontrollerscript
{
  local CONTROLLERIP=$1
  echo "running controller $CONTROLLERIP"
  scp ${WORKSPACE}/deploy-controller-script.sh $CONTROLLERIP:/tmp
  ssh $CONTROLLERIP 'bash /tmp/deploy-controller-script.sh'
}

function sanitytestcontroller
{
  local CONTROLLERIP=$1
  echo "sanity testing controller $CONTROLLERIP"
  scp ${WORKSPACE}/deploy-sanitytest-controller-script.sh $CONTROLLERIP:/tmp
  ssh $CONTROLLERIP 'bash /tmp/deploy-sanitytest-controller-script.sh'
}

echo "##################################"
echo "##  Loop through controller IPs  #"
echo "##################################"

declare CONTROLLERIPS=($(cat slave_addresses.txt | grep CONTROLLER | awk -F = '{print $2}'))

for  i in "${CONTROLLERIPS[@]}"
do
   echo "IP address is: $i"
   runcontrollerscript $i
done

for  i in "${CONTROLLERIPS[@]}"
do
   echo "IP address is: $i"
   sanitytestcontroller $i
done

echo "###################################################"
echo "## END include-raw-integration-deploy-controller ##"
echo "###################################################"

# vim: ts=4 sw=4 sts=4 et ft=sh :

