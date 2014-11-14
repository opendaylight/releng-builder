# redefine our TMP space
export TMP=/tmp/jenkins-integration-controller
pidfile="${TMP}/opendaylight.PID"

# is controller running?
cat <<EOF > ${WORKSPACE}/checkrunning
if [ -e "${pidfile}" ]; then
    daemonpid=\`cat ${pidfile}\`
    ps -p \${daemonpid} > /dev/null
    daemonexists=\$?
    if [ "\${daemonexists}" -eq 0 ]; then
        echo running
    else
        echo not-running
    fi
else
    echo not-running
fi
EOF

# kill the old karaf controller if any
RET=`/bin/sh ${WORKSPACE}/checkrunning`
if [ "${RET}" == 'running' ]; then
    ODLPID=`cat "${pidfile}"`
    kill "${ODLPID}"
    rm -f "${pidfile}"
    echo "Controller with PID: ${ODLPID}  -- Stopped!"
    sleep 5
fi

# clear out the current workspace
rm -rf ./*

# create our new tmp space (we do it here in case we recently just finished cleaning)
mkdir -p ${TMP}

# download the artifact
wget ${BUNDLEURL}

# extract the new controller
BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
BUNDLEFOLDER="${BUNDLE//.zip}"
unzip -q ${BUNDLE}

# Configure the controller
cd ${BUNDLEFOLDER}/etc
# Configure the startup features
export CFG=org.apache.karaf.features.cfg
cp ${CFG} ${CFG}.bak
cat ${CFG}.bak | sed 's/featuresBoot=config\,standard\,region\,package\,kar\,ssh\,management/featuresBoot=config\,standard\,region\,package\,kar\,ssh\,management\,odl-openflowplugin-flow-services-ui\,odl-nsf-all\,odl-adsal-compatibility\,odl-netconf-connector-ssh/' > ${CFG}
# Configure the log
export LOG=org.ops4j.pax.logging.cfg
cp ${LOG} ${LOG}.bak
cat ${LOG}.bak | sed 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/' > ${LOG}

# run the controller but trick jenkins into not killing it
cd ../bin
BUILD_ID=dontKillMe ./start

# sleep for 300 seconds may need to be longer
sleep 150

# Check OSGi bundles
./client 'bundle:list'

# Getting ODL PID to store in common file
cd ../instances
ODLPID=`grep pid instance.properties | awk -F ' ' '{print $3}'`
echo ${ODLPID}
ps -p ${ODLPID}
echo ${ODLPID} > ${pidfile}

# copy karaf log
cd ${WORKSPACE}
cp ${BUNDLEFOLDER}/data/log/karaf.log .
