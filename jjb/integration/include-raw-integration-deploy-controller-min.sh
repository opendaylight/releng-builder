# Create a script to run controller inside a dynamic jenkins slave
cat > ${WORKSPACE}/controller-script.sh <<EOF
# redefine our TMP space
export TMP=/tmp/jenkins-integration-controller
pidfile="\${TMP}/opendaylight.PID"

# create our new tmp space (we do it here in case we recently just finished cleaning)
mkdir -p \${TMP}

# download the artifact
cd /tmp
wget --no-verbose  ${BUNDLEURL}

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
cat \${CFG}.bak | sed "s/^featuresBoot=.*/featuresBoot=${CONTROLLERFEATURES}/" > \${CFG}
# Configure the log
export LOG=org.ops4j.pax.logging.cfg
cp \${LOG} \${LOG}.bak
cat \${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > \${LOG}

cat \${CFG}
cat \${LOG}

# run the controller but trick jenkins into not killing it
cd ../bin

#BUILD_ID=dontKillMe ./start
./start & 


ps -ef | grep java

# sleep for 300 seconds may need to be longer
sleep 150

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
