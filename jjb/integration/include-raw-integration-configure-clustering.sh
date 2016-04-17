echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf

# Utility function for joining strings.
function join {
    delim=' '
    final=$1; shift

    for str in $* ; do
        final=${final}${delim}${str}
    done

    echo ${final}
}

# Create the string for nodes

for i in `seq 1 ${NUM_ODL_SYSTEM}` ; do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    nodes[$i]=${!CONTROLLERIP}
done

nodes_list=$(join ${nodes[@]})

echo ${nodes_list}

# Create the configuration script to be run on controllers.
cat > ${WORKSPACE}/configuration-script.sh <<EOF

echo "Configuring cluster"
/tmp/${BUNDLEFOLDER}/bin/configure_cluster.sh \$1 ${nodes_list}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}

echo "Set Java version"
sudo /usr/sbin/alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
sudo /usr/sbin/alternatives --set java ${JAVA_HOME}/bin/java
echo "JDK default version ..."
java -version

echo "Set JAVA_HOME"
export JAVA_HOME="${JAVA_HOME}"
# Did you know that in HERE documents, single quote is an ordinary character, but backticks are still executing?
JAVA_RESOLVED=\`readlink -e "\${JAVA_HOME}/bin/java"\`
echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

# Copy over the configuration script and configuration files to each controller
# Execute the configuration script on each controller.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Configuring member-${i} with IP address ${!CONTROLLERIP}"
    scp  ${WORKSPACE}/configuration-script.sh    ${!CONTROLLERIP}:/tmp/
    ssh ${!CONTROLLERIP} "bash /tmp/configuration-script.sh ${i}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

