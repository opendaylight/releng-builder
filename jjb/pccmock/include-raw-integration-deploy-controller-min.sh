# Create a script to run controller inside a dynamic jenkins slave
CONTROLLERMEM="2048m"

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-karaf"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo Bundle version is $BUNDLEVERSION
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo Nexus timestamp is $TIMESTAMP
    BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
    BUNDLE="distribution-karaf-${TIMESTAMP}.zip"
    BUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
    echo Distribution bundle URL is ${BUNDLEURL}
else
    BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
    BUNDLEFOLDER="${BUNDLE//.zip}"
fi

cat > ${WORKSPACE}/controller-script.sh <<EOF
echo Downloading the distribution from ${BUNDLEURL}
cd /tmp
wget --no-verbose  ${BUNDLEURL}

echo Extracting the new controller...
unzip -q ${BUNDLE}

echo Configuring the startup features...
cd ${BUNDLEFOLDER}/etc
export CFG=org.apache.karaf.features.cfg
cp \${CFG} \${CFG}.bak
cat \${CFG}.bak | sed "s/^featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${CONTROLLERFEATURES}/" > \${CFG}
cat \${CFG}

echo Configuring the log...
export LOG=org.ops4j.pax.logging.cfg
cp \${LOG} \${LOG}.bak
cat \${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > \${LOG}
cat \${LOG}

echo Configure max memory...
export MEM=setenv
cd ../bin
cp \${MEM} \${MEM}.bak
cat \${MEM}.bak | sed 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/' > \${MEM}
cat \${MEM}

echo Starting controller...
./start &

echo Waiting for controller to come up...
COUNT="0"
while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [[ \$RESP == *"200"* ]]; then
        echo Controller is UP
        break
    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN
        break
    else
        COUNT=\$(( \${COUNT} + 5 ))
        sleep 5
        echo waiting \$COUNT secs...
    fi
done

echo Cool down for 1 min...
sleep 60

echo Checking OSGi bundles
./client 'bundle:list'

EOF

scp ${WORKSPACE}/controller-script.sh $CONTROLLER0:/tmp
ssh $CONTROLLER0 'bash /tmp/controller-script.sh'

echo Fetching Karaf log
scp $CONTROLLER0:/tmp/$BUNDLEFOLDER/data/log/karaf.log .

# vim: ts=4 sw=4 sts=4 et ft=sh :
