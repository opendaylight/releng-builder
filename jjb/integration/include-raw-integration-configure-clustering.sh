echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
JOLOKIACONF=/tmp/${BUNDLEFOLDER}/deploy/jolokia.xml

# Utility function for joining strings.
function join {
    delim=',\n\t\t'
    final=$1; shift

    for str in $* ; do
	final=${final}${delim}${str}
    done

    echo ${final}
}

# Create the strings for data and rpc seed nodes
# First create various arrays with one element per controller.
# Then merge each array using the join utility defined above.

for i in `seq 1 ${NUM_ODL_SYSTEM}` ; do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    data_seed_nodes[$i]=\\\"akka.tcp:\\/\\/opendaylight-cluster-data@${!CONTROLLERIP}:2550\\\"
    rpc_seed_nodes[$i]=\\\"akka.tcp:\\/\\/odl-cluster-rpc@${!CONTROLLERIP}:2551\\\"
    member_names[$i]=\\\"member-${i}\\\"
done

data_seed_list=$(join ${data_seed_nodes[@]})
rpc_seed_list=$(join ${rpc_seed_nodes[@]})
member_name_list=$(join ${member_names[@]})

# echo ${data_seed_list}
# echo ${rpc_seed_list}
# echo ${member_name_list}

# Create the configuration script to be run on controllers.
cat > ${WORKSPACE}/configuration-script.sh <<EOF

CONTROLLERID="member-\$1"
CONTROLLERIP=\$2

echo "Configuring hostname in akka.conf"
sed -i -e "s:{{HOST}}:\${CONTROLLERIP}:" ${AKKACONF}

echo "Configuring data seed nodes in akka.conf"
sed -i -e "s/{{{DS_SEED_NODES}}}/[${data_seed_list}]/g" ${AKKACONF}

echo "Configuring rpc seed nodes in akka.conf"
sed -i -e "s/{{{RPC_SEED_NODES}}}/[${rpc_seed_list}]/g" ${AKKACONF}

echo "Define unique name in akka.conf"
sed -i -e "s/{{MEMBER_NAME}}/\${CONTROLLERID}/g" ${AKKACONF}

echo "Define replication type in module-shards.conf"
sed -i -e "s/{{{REPLICAS_1}}}/[${member_name_list}]/g" ${MODULESHARDSCONF}
sed -i -e "s/{{{REPLICAS_2}}}/[${member_name_list}]/g" ${MODULESHARDSCONF}
sed -i -e "s/{{{REPLICAS_3}}}/[${member_name_list}]/g" ${MODULESHARDSCONF}
sed -i -e "s/{{{REPLICAS_4}}}/[${member_name_list}]/g" ${MODULESHARDSCONF}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

# Copy over the configuration script and configuration files to each controller
# Execute the configuration script on each controller.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Configuring member-${i} with IP address ${!CONTROLLERIP}"
    ssh ${!CONTROLLERIP} "mkdir /tmp/${BUNDLEFOLDER}/configuration/initial"
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/akka.conf.template ${!CONTROLLERIP}:${AKKACONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/modules.conf.template ${!CONTROLLERIP}:${MODULESCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/module-shards.conf.template ${!CONTROLLERIP}:${MODULESHARDSCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/jolokia.xml.template ${!CONTROLLERIP}:${JOLOKIACONF}
    scp  ${WORKSPACE}/configuration-script.sh    ${!CONTROLLERIP}:/tmp/
    ssh ${!CONTROLLERIP} "bash /tmp/configuration-script.sh ${i} ${!CONTROLLERIP}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

