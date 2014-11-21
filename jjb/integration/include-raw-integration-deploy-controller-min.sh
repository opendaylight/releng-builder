# Create a script to run controller inside a dynamic jenkins slave
cat > ${WORKSPACE}/controller-script.sh <<EOF
# redefine our TMP space
export TMP=/tmp/jenkins-integration-controller
pidfile="\${TMP}/opendaylight.PID"

# create our new tmp space (we do it here in case we recently just finished cleaning)
mkdir -p \${TMP}

# download the artifact
cd /tmp
wget --no-verbose ${BUNDLEURL}

# extract the new controller
cd \${TMP}
BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
BUNDLEFOLDER="\${BUNDLE//.zip}"
unzip -q /tmp/\${BUNDLE}

# Configure the controller
cd \${BUNDLEFOLDER}/etc

# Configure the startup features
export CFG=org.apache.karaf.features.cfg
cp \${CFG} \${CFG}.bak
cat \${CFG}.bak | sed 's/^featuresBoot=.*/featuresBoot=${CONTROLLER_FEATURES}/' > \${CFG}

# Configure the log
export LOG=org.ops4j.pax.logging.cfg
cp \${LOG} \${LOG}.bak
cat \${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > \${LOG}

# Configure Max memory
if [ '${CONTROLLER_MEM != "2048m" ']; then
    cd ../bin
    cp setenv setenv.bak
    cat setenv.bak | sed 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLER_MEM}"/' > setenv
fi



# run the controller but trick jenkins into not killing it
cd ../bin
BUILD_ID=dontKillMe ./start

# sleep for 300 seconds may need to be longer
sleep 150

# Loading up all compatible features if CONTROLLER_ALL is true
if [ '${CONTROLLER_ALL}' ]; then
    ./client 'feature:install odl-integration-compatible-with-all' 
fi

# Check OSGi bundles
./client 'bundle:list'

# Getting ODL PID to store in common file
cd ../instances
ODLPID=\`grep pid instance.properties | awk -F ' ' '{print \$3}'\`
echo \${ODLPID}
ps -p \${ODLPID}
echo \${ODLPID} > \${pidfile}

ls \${TMP}
EOF

scp ${WORKSPACE}/controller-script.sh $CONTROLLER0:/tmp
ssh $CONTROLLER0 'bash /tmp/controller-script.sh'

# vim: ts=4 sw=4 sts=4 et ft=sh :
