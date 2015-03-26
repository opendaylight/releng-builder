echo "#################################################"
echo "##   include-raw-integration-deploy-controller ##"
echo "#################################################"

# Create a script to run controller inside a dynamic jenkins slave
CONTROLLERMEM="2048m"
DISTRIBUTION="karaf"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    CONTROLLERFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
    if [ ${BRANCH} == 'master' ]; then
        DISTRIBUTION="test"
    fi
fi

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-${DISTRIBUTION}"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is $BUNDLEVERSION"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo "Nexus timestamp is $TIMESTAMP"
    BUNDLEFOLDER="distribution-${DISTRIBUTION}-${BUNDLEVERSION}"
    BUNDLE="distribution-${DISTRIBUTION}-${TIMESTAMP}.zip"
    BUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
    echo "Distribution bundle URL is ${BUNDLEURL}"
else
    BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
    BUNDLEFOLDER="${BUNDLE//.zip}"
fi

cat > ${WORKSPACE}/deploy-controller-script.sh <<EOF
echo "Downloading the distribution from ${BUNDLEURL}"
cd /tmp
wget --no-verbose  ${BUNDLEURL}

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

./stop &


EOF






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

echo "##################################"
echo "##  Loop through controller IPs  #"
echo "##################################"

declare CONTROLLERIPS=($(cat slave_addresses.txt | grep CONTROLLER | awk -F = '{print $2}'))

for  i in "${CONTROLLERIPS[@]}"
do
   echo "IP address is: $i"
   runcontrollerscript $i
done


echo "###################################################"
echo "## END include-raw-integration-deploy-controller ##"
echo "###################################################"

# vim: ts=4 sw=4 sts=4 et ft=sh :

