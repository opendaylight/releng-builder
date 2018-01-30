#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate

echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    export CONTROLLERMEM="3072m"
else
    ACTUALFEATURES="odl-infrautils-ready,${CONTROLLERFEATURES}"
fi
# Some versions of jenkins job builder result in feature list containing spaces
# and ending in newline. Remove all that.
ACTUALFEATURES=`echo "${ACTUALFEATURES}" | tr -d '\n \r'`

# Utility function for joining strings.
function join {
    delim=' '
    final=$1; shift

    for str in "$@" ; do
        final=${final}${delim}${str}
    done

    echo ${final}
}

# Create the string for nodes
for i in `seq 1 ${NUM_ODL_SYSTEM}` ; do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    nodes[$i]=${!CONTROLLERIP}
done

nodes_list=$(join "${nodes[@]}")

echo ${nodes_list}

# Run script plan in case it exists
if [ -f ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} ]; then
    echo "scriptplan exists!!!"
    echo "Reading the scriptplan:"
    cat ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > scriptplan.txt
    cat scriptplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' scriptplan.txt ); do
        echo "Executing ${line}..."
        source ${line}
    done
fi

# Create the configuration script to be run on controllers.
cat > ${WORKSPACE}/configuration-script.sh <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution from ${ACTUAL_BUNDLE_URL}"
wget --progress=dot:mega  '${ACTUAL_BUNDLE_URL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Adding external repositories..."
sed -ie "s%org.ops4j.pax.url.mvn.repositories=%org.ops4j.pax.url.mvn.repositories=http://repo1.maven.org/maven2@id=central, http://repository.springsource.com/maven/bundles/release@id=spring.ebr.release, http://repository.springsource.com/maven/bundles/external@id=spring.ebr.external, http://zodiac.springsource.com/maven/bundles/release@id=gemini, http://repository.apache.org/content/groups/snapshots-group@id=apache@snapshots@noreleases, https://oss.sonatype.org/content/repositories/snapshots@id=sonatype.snapshots.deploy@snapshots@noreleases, https://oss.sonatype.org/content/repositories/ops4j-snapshots@id=ops4j.sonatype.snapshots.deploy@snapshots@noreleases%g" ${MAVENCONF}
cat ${MAVENCONF}

echo "Configuring the startup features..."
sed -ie "s/\(featuresBoot=\|featuresBoot =\)/featuresBoot = ${ACTUALFEATURES},/g" ${FEATURESCONF}

FEATURE_TEST_STRING="features-integration-test"
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    FEATURE_TEST_STRING="features-test"
fi

sed -ie "s%\(featuresRepositories=\|featuresRepositories =\)%featuresRepositories = mvn:org.opendaylight.integration/\${FEATURE_TEST_STRING}/${BUNDLEVERSION}/xml/features,mvn:org.apache.karaf.decanter/apache-karaf-decanter/1.0.0/xml/features,%g" ${FEATURESCONF}
cat ${FEATURESCONF}

configure_karaf_log

set_java_vars

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
  echo "Enable the l3.fwd in custom.properties.."
  echo "ovsdb.l3.fwd.enabled=yes" >> ${CUSTOMPROP}
  cat ${CUSTOMPROP}
fi

# Copy shard file if exists
if [ -f /tmp/custom_shard_config.txt ]; then
    echo "Custom shard config exists!!!"
    echo "Copying the shard config..."
    cp /tmp/custom_shard_config.txt /tmp/${BUNDLEFOLDER}/bin/
fi

echo "Configuring cluster"
/tmp/${BUNDLEFOLDER}/bin/configure_cluster.sh \$1 ${nodes_list}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}

EOF

# Create the startup script to be run on controllers.
cat > ${WORKSPACE}/startup-script.sh <<EOF

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p /tmp/${BUNDLEFOLDER}/data/log

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

# Copy over the configuration script and configuration files to each controller
# Execute the configuration script on each controller.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Configuring member-${i} with IP address ${!CONTROLLERIP}"
    scp ${WORKSPACE}/configuration-script.sh ${!CONTROLLERIP}:/tmp/
    ssh ${!CONTROLLERIP} "bash /tmp/configuration-script.sh ${i}"
done

# Run config plan in case it exists
configplan_filepath="${WORKSPACE}/test/csit/configplans/${STREAMTESTPLAN}"
if [ ! -f "${configplan_filepath}" ]; then
    configplan_filepath="${WORKSPACE}/test/csit/configplans/${TESTPLAN}"
fi

if [ -f ${configplan_filepath} ]; then
    echo "configplan exists!!!"
    echo "Reading the configplan:"
    cat ${configplan_filepath} | sed "s:integration:${WORKSPACE}:" > configplan.txt
    cat configplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' configplan.txt ); do
        echo "Executing ${line}..."
        source ${line}
    done
fi

# Copy over the startup script to each controller and execute it.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Starting member-${i} with IP address ${!CONTROLLERIP}"
    scp ${WORKSPACE}/startup-script.sh ${!CONTROLLERIP}:/tmp/
    ssh ${!CONTROLLERIP} "bash /tmp/startup-script.sh"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :
