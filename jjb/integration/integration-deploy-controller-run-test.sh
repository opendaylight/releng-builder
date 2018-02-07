#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate
source /tmp/common-functions.sh ${BUNDLEFOLDER}

if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
    echo "Configure cluster"
    AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
    MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
    MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
fi

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    export CONTROLLERMEM="3072m"
    COOLDOWN_PERIOD="180"
else
    ACTUALFEATURES="odl-infrautils-ready,${CONTROLLERFEATURES}"
    COOLDOWN_PERIOD="60"
fi

# Some versions of jenkins job builder result in feature list containing spaces
# and ending in newline. Remove all that.
ACTUALFEATURES=`echo "${ACTUALFEATURES}" | tr -d '\n \r'`
echo "ACTUALFEATURES: ${ACTUALFEATURES}"

# In the case that we want to install features via karaf shell, a space separated list of
# ACTUALFEATURES IS NEEDED
SPACE_SEPARATED_FEATURES=$(echo "${ACTUALFEATURES}" | tr ',' ' ')
echo "SPACE_SEPARATED_FEATURES: ${SPACE_SEPARATED_FEATURES}"

if [ -f "${WORKSPACE}/test/csit/scriptplans/${TESTPLAN}" ]; then
    echo "scriptplan exists!!!"
    echo "Changing the scriptplan path..."
    cat ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > scriptplan.txt
    cat scriptplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' scriptplan.txt ); do
        echo "Executing ${line}..."
        # shellcheck source=${line} disable=SC1091
        source ${line}
    done
fi

cat > ${WORKSPACE}/configuration-script.sh <<EOF
set -x
source /tmp/common-functions.sh ${BUNDLEFOLDER}

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution..."
wget --progress=dot:mega '${ACTUAL_BUNDLE_URL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Adding external repositories..."
sed -ie "s%org.ops4j.pax.url.mvn.repositories=%org.ops4j.pax.url.mvn.repositories=http://repo1.maven.org/maven2@id=central, http://repository.springsource.com/maven/bundles/release@id=spring.ebr.release, http://repository.springsource.com/maven/bundles/external@id=spring.ebr.external, http://zodiac.springsource.com/maven/bundles/release@id=gemini, http://repository.apache.org/content/groups/snapshots-group@id=apache@snapshots@noreleases, https://oss.sonatype.org/content/repositories/snapshots@id=sonatype.snapshots.deploy@snapshots@noreleases, https://oss.sonatype.org/content/repositories/ops4j-snapshots@id=ops4j.sonatype.snapshots.deploy@snapshots@noreleases%g" ${MAVENCONF}
cat ${MAVENCONF}

if [[ "$USEFEATURESBOOT" == "True" ]]; then
    echo "Configuring the startup features..."
    sed -ie "s/\(featuresBoot=\|featuresBoot =\)/featuresBoot = ${ACTUALFEATURES},/g" ${FEATURESCONF}
fi

FEATURE_TEST_STRING="features-integration-test"
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    FEATURE_TEST_STRING="features-test"
fi

sed -ie "s%\(featuresRepositories=\|featuresRepositories =\)%featuresRepositories = mvn:org.opendaylight.integration/\${FEATURE_TEST_STRING}/${BUNDLEVERSION}/xml/features,mvn:org.apache.karaf.decanter/apache-karaf-decanter/1.0.0/xml/features,%g" ${FEATURESCONF}
cat ${FEATURESCONF}

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
    echo "Enable the l3.fwd in custom.properties..."
    echo "ovsdb.l3.fwd.enabled=yes" >> ${CUSTOMPROP}
fi
cat ${CUSTOMPROP}

configure_karaf_log "${KARAF_VERSION}" "${CONTROLLERDEBUGMAP}"

set_java_vars "${JAVA_HOME}" "${CONTROLLERMEM}"

echo "Listing all open ports on controller system..."
netstat -pnatu

if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then

    # Copy shard file if exists
    if [ -f /tmp/custom_shard_config.txt ]; then
        echo "Custom shard config exists!!!"
        echo "Copying the shard config..."
        cp /tmp/custom_shard_config.txt /tmp/${BUNDLEFOLDER}/bin/
    fi

    echo "Configuring cluster"
    /tmp/${BUNDLEFOLDER}/bin/configure_cluster.sh \$1 \$2

    echo "Dump akka.conf"
    cat ${AKKACONF}

    echo "Dump modules.conf"
    cat ${MODULESCONF}

     echo "Dump module-shards.conf"
     cat ${MODULESHARDSCONF}
fi

EOF
# cat > ${WORKSPACE}/configuration-script.sh <<EOF

# Create the startup script to be run on controller.
cat > ${WORKSPACE}/startup-script.sh <<EOF

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p /tmp/${BUNDLEFOLDER}/data/log

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF
# cat > ${WORKSPACE}/startup-script.sh <<EOF

cat > ${WORKSPACE}/post-startup-script.sh <<EOF

if [[ "$USEFEATURESBOOT" != "True" ]]; then

    # wait up to 60s for karaf port 8101 to be opened, polling every 5s
    loop_count=0;
    until [[ \$loop_count -ge 12 ]]; do
        netstat -na | grep 8101 && break;
        loop_count=\$[\$loop_count+1];
        sleep 5;
    done

    echo "going to feature:install --no-auto-refresh ${SPACE_SEPARATED_FEATURES} one at a time"
    for feature in ${SPACE_SEPARATED_FEATURES}; do
        sshpass -p karaf ssh -o StrictHostKeyChecking=no \
                             -o UserKnownHostsFile=/dev/null \
                             -o LogLevel=error \
                             -p 8101 karaf@localhost \
                             feature:install --no-auto-refresh \$feature;
    done

    echo "ssh to karaf console to list -i installed features"
    sshpass -p karaf ssh -o StrictHostKeyChecking=no \
                         -o UserKnownHostsFile=/dev/null \
                         -o LogLevel=error \
                         -p 8101 karaf@localhost \
                         feature:list -i
fi

echo "Waiting for controller to come up..."
COUNT="0"
while true; do
    RESP="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/restconf/modules -o /dev/null )"
    echo \$RESP
    if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
        SHARD="\$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://localhost:8181/jolokia/read/org.opendaylight.controller:Category=Shards,name=\member-\$1-shard-inventory-config,type=DistributedConfigDatastore)"
        echo \$SHARD
    fi
    if ([[ \$RESP == *"200"* ]] && ([[ "${ENABLE_HAPROXY_FOR_NEUTRON}" != "yes" ]] || [[ \$SHARD  == *'"status":200'* ]])); then
        echo Controller is UP
        break
    elif (( "\$COUNT" > "600" )); then
        echo Timeout Controller DOWN
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Listing all open ports on controller system"
        netstat -pnatu
        exit 1
    else
        COUNT=\$(( \${COUNT} + 1 ))
        sleep 1
        if [[ \$((\$COUNT % 5)) == 0 ]]; then
            echo already waited \${COUNT} seconds...
        fi
    fi
done

echo "Listing all open ports on controller system..."
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"; then
        echo ABORTING: found "\$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

EOF
# cat > ${WORKSPACE}/post-startup-script.sh <<EOF

[ "$NUM_OPENSTACK_SITES" ] || NUM_OPENSTACK_SITES=1
NUM_ODLS_PER_SITE=$((NUM_ODL_SYSTEM / NUM_OPENSTACK_SITES))
for i in `seq 1 ${NUM_OPENSTACK_SITES}`
do
    # Get full list of ODL nodes for this site
    odl_node_list=
    for j in `seq 1 ${NUM_ODLS_PER_SITE}`
    do
        odl_ip=ODL_SYSTEM_$(((i - 1) * NUM_ODLS_PER_SITE + j))_IP
        odl_node_list="${odl_node_list} ${!odl_ip}"
    done

    for j in `seq 1 ${NUM_ODLS_PER_SITE}`
    do
        odl_ip=ODL_SYSTEM_$(((i - 1) * NUM_ODLS_PER_SITE + j))_IP
        # Copy over the config script to controller and execute it (parameters are used only for cluster)
        echo "Execute the configuration script on controller ${!odl_ip} for index $j with node list ${odl_node_list}"
        scp ${WORKSPACE}/configuration-script.sh ${!odl_ip}:/tmp
        ssh ${!odl_ip} "bash /tmp/configuration-script.sh ${j} '${odl_node_list}'"
    done
done

echo "Locating config plan to use..."
configplan_filepath="${WORKSPACE}/test/csit/configplans/${STREAMTESTPLAN}"
if [ ! -f "${configplan_filepath}" ]; then
    configplan_filepath="${WORKSPACE}/test/csit/configplans/${TESTPLAN}"
fi

if [ -f "${configplan_filepath}" ]; then
    echo "configplan exists!!!"
    echo "Changing the configplan path..."
    cat ${configplan_filepath} | sed "s:integration:${WORKSPACE}:" > configplan.txt
    cat configplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' configplan.txt ); do
        echo "Executing ${line}..."
        # shellcheck source=${line} disable=SC1091
        source ${line}
    done
fi

# Copy over the startup script to controller and execute it.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Execute the startup script on controller ${!CONTROLLERIP}"
    scp ${WORKSPACE}/startup-script.sh ${!CONTROLLERIP}:/tmp
    ssh ${!CONTROLLERIP} "bash /tmp/startup-script.sh"
done

seed_index=1
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Execute the post startup script on controller ${!CONTROLLERIP}"
    scp ${WORKSPACE}/post-startup-script.sh ${!CONTROLLERIP}:/tmp
    ssh ${!CONTROLLERIP} "bash /tmp/post-startup-script.sh $(( seed_index++ ))"
    if [ $(( $i % (${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 0 ]; then
        seed_index=1
    fi
done

echo "Cool down for ${COOLDOWN_PERIOD} seconds :)..."
sleep ${COOLDOWN_PERIOD}

echo "Generating controller variables..."
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    odl_variables=${odl_variables}" -v ${CONTROLLERIP}:${!CONTROLLERIP}"
    echo "Lets's take the karaf thread dump"
    ssh ${!CONTROLLERIP} "sudo ps aux" > ${WORKSPACE}/ps_before.log
    pid=$(grep org.apache.karaf.main.Main ${WORKSPACE}/ps_before.log | grep -v grep | tr -s ' ' | cut -f2 -d' ')
    echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
    ssh ${!CONTROLLERIP} "jstack ${pid}" > ${WORKSPACE}/karaf_${i}_${pid}_threads_before.log || true
done

if [ ${NUM_OPENSTACK_SYSTEM} -gt 0 ]; then
   echo "Exiting without running tests to deploy openstack for testing"
   exit
fi

echo "Generating mininet variables..."
for i in `seq 1 ${NUM_TOOLS_SYSTEM}`
do
    MININETIP=TOOLS_SYSTEM_${i}_IP
    tools_variables=${tools_variables}" -v ${MININETIP}:${!MININETIP}"
done

echo "Locating test plan to use..."
testplan_filepath="${WORKSPACE}/test/csit/testplans/${STREAMTESTPLAN}"
if [ ! -f "${testplan_filepath}" ]; then
    testplan_filepath="${WORKSPACE}/test/csit/testplans/${TESTPLAN}"
fi

echo "Changing the testplan path..."
cat "${testplan_filepath}" | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

# Use the testplan if specific SUITES are not defined.
if [ -z "${SUITES}" ]; then
    SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`
else
    newsuites=""
    workpath="${WORKSPACE}/test/csit/suites"
    for suite in ${SUITES}; do
        fullsuite="${workpath}/${suite}"
        if [ -z "${newsuites}" ]; then
            newsuites+=${fullsuite}
        else
            newsuites+=" "${fullsuite}
        fi
    done
    SUITES=${newsuites}
fi

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} --removekeywords wuks -c critical -e exclude -e skip_if_${DISTROSTREAM} -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v JAVA_HOME:${JAVA_HOME} -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
-v CONTROLLER:${ODL_SYSTEM_IP} -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_IP} \
-v CONTROLLER_USER:${USER} -v ODL_SYSTEM_USER:${USER} \
-v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
-v TOOLS_SYSTEM_4_IP:${TOOLS_SYSTEM_4_IP} -v TOOLS_SYSTEM_5_IP:${TOOLS_SYSTEM_5_IP} -v TOOLS_SYSTEM_6_IP:${TOOLS_SYSTEM_6_IP} \
-v TOOLS_SYSTEM_USER:${USER} -v JDKVERSION:${JDKVERSION} -v ODL_STREAM:${DISTROSTREAM} -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} \
-v MININET3:${TOOLS_SYSTEM_4_IP} -v MININET4:${TOOLS_SYSTEM_5_IP} -v MININET5:${TOOLS_SYSTEM_6_IP} \
-v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true
# FIXME: Sort (at least -v) options alphabetically.

echo "Examining the files in data/log and checking filesize"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Lets's take the karaf thread dump again..."
    ssh ${!CONTROLLERIP} "sudo ps aux" > ${WORKSPACE}/ps_after.log
    pid=$(grep org.apache.karaf.main.Main ${WORKSPACE}/ps_after.log | grep -v grep | tr -s ' ' | cut -f2 -d' ')
    echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
    ssh ${!CONTROLLERIP} "jstack ${pid}" > ${WORKSPACE}/karaf_${i}_${pid}_threads_after.log || true
    echo "Killing ODL"
    set +e  # We do not want to create red dot just because something went wrong while fetching logs.
    ssh "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done

sleep 5
# FIXME: Unify the copy process between various scripts.
# TODO: Use rsync.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Compressing karaf.log ${i}"
    ssh ${!CONTROLLERIP} gzip --best /tmp/${BUNDLEFOLDER}/data/log/karaf.log
    echo "Fetching compressed karaf.log ${i}"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz" "odl${i}_karaf.log.gz" && ssh ${!CONTROLLERIP} rm -f "/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz"
    # TODO: Should we compress the output log file as well?
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log" "odl${i}_karaf_console.log" && ssh ${!CONTROLLERIP} rm -f "/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"
    echo "Fetch GC logs"
    # FIXME: Put member index in filename, instead of directory name.
    mkdir -p "gclogs-${i}"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/*.log" "gclogs-${i}/" && ssh ${!CONTROLLERIP} rm -f "/tmp/${BUNDLEFOLDER}/data/log/*.log"
done

echo "Examine copied files"
ls -lt

true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :
