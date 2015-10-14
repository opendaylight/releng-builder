echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
JOLOKIACONF=/tmp/${BUNDLEFOLDER}/deploy/jolokia.xml

cat > ${WORKSPACE}/configuration-script.sh <<EOF

CONTROLLERID="member-\$1"
ODL_SYSTEM_IP_PATH=\$2

echo "Configuring hostname in akka.conf"
sed -ie "s:{{HOST}}:\${ODL_SYSTEM_IP_PATH}:" ${AKKACONF}

echo "Configuring data seed nodes in akka.conf"
sed -ie "s/{{{DS_SEED_NODES}}}/[\"akka.tcp:\/\/opendaylight-cluster-data@$ODL_SYSTEM_IP:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$ODL_SYSTEM_2_IP:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$ODL_SYSTEM_3_IP:2550\"]/g" ${AKKACONF}

echo "Configuring rpc seed nodes in akka.conf"
sed -ie "s/{{{RPC_SEED_NODES}}}/[\"akka.tcp:\/\/odl-cluster-rpc@$ODL_SYSTEM_IP:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$ODL_SYSTEM_2_IP:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$ODL_SYSTEM_3_IP:2551\"]/g" ${AKKACONF}

echo "Define unique name in akka.conf"
sed -ie "s/{{MEMBER_NAME}}/\$CONTROLLERID/g" ${AKKACONF}

echo "Define replication type in module-shards.conf"
sed -ie "s/{{{REPLICAS_1}}}/[\"member-1\",\n\t\t\t\"member-2\",\n\t\t\t\"member-3\"]/g" ${MODULESHARDSCONF}
sed -ie "s/{{{REPLICAS_2}}}/[\"member-1\",\n\t\t\t\"member-2\",\n\t\t\t\"member-3\"]/g" ${MODULESHARDSCONF}
sed -ie "s/{{{REPLICAS_3}}}/[\"member-1\",\n\t\t\t\"member-2\",\n\t\t\t\"member-3\"]/g" ${MODULESHARDSCONF}
sed -ie "s/{{{REPLICAS_4}}}/[\"member-1\",\n\t\t\t\"member-2\",\n\t\t\t\"member-3\"]/g" ${MODULESHARDSCONF}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}

echo "Increase soft limit for number of open files..."
id
ulimit -Sn 16000

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

ODL_SYSTEM_IPS=(${ODL_SYSTEM_IP} ${ODL_SYSTEM_2_IP} ${ODL_SYSTEM_3_IP})
for i in "${!ODL_SYSTEM_IPS[@]}"
do
    echo "Configuring member-$((i+1)) with IP address ${ODL_SYSTEM_IPS[$i]}"
    ssh ${ODL_SYSTEM_IPS[$i]} "mkdir /tmp/${BUNDLEFOLDER}/configuration/initial"
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/akka.conf.template ${ODL_SYSTEM_IPS[$i]}:${AKKACONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/modules.conf.template ${ODL_SYSTEM_IPS[$i]}:${MODULESCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/module-shards.conf.template ${ODL_SYSTEM_IPS[$i]}:${MODULESHARDSCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/jolokia.xml.template ${ODL_SYSTEM_IPS[$i]}:${JOLOKIACONF}
    scp  ${WORKSPACE}/configuration-script.sh    ${ODL_SYSTEM_IPS[$i]}:/tmp/
    ssh ${ODL_SYSTEM_IPS[$i]} "bash /tmp/configuration-script.sh $((i+1)) ${ODL_SYSTEM_IPS[$i]}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

