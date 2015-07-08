echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
JOLOKIACONF=/tmp/${BUNDLEFOLDER}/deploy/jolokia.xml

cat > ${WORKSPACE}/configuration-script.sh <<EOF

CONTROLLERID="member-\$1"
CONTROLLERIP=\$2

echo "Configuring hostname in akka.conf"
sed -ie "s:{{HOST}}:\${CONTROLLERIP}:" ${AKKACONF}

echo "Configuring data seed nodes in akka.conf"
sed -ie "s/{{{DS_SEED_NODES}}}/[\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER0:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER1:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER2:2550\"]/g" ${AKKACONF}

echo "Configuring rpc seed nodes in akka.conf"
sed -ie "s/{{{RPC_SEED_NODES}}}/[\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER0:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER1:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER2:2551\"]/g" ${AKKACONF}

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

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

CONTROLLERIPS=(${CONTROLLER0} ${CONTROLLER1} ${CONTROLLER2})
for i in "${!CONTROLLERIPS[@]}"
do
    echo "Configuring member-${i+1} with IP address ${CONTROLLERIPS[$i]}"
    ssh ${CONTROLLERIPS[$i]} "mkdir /tmp/${BUNDLEFOLDER}/configuration/initial"
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/akka.conf.template ${CONTROLLERIPS[$i]}:${AKKACONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/modules.conf.template ${CONTROLLERIPS[$i]}:${MODULESCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/module-shards.conf.template ${CONTROLLERIPS[$i]}:${MODULESHARDSCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/multi-node-test/jolokia.xml.template ${CONTROLLERIPS[$i]}:${JOLOKIACONF}
    scp  ${WORKSPACE}/configuration-script.sh    ${CONTROLLERIPS[$i]}:/tmp/
    ssh ${CONTROLLERIPS[$i]} "bash /tmp/configuration-script.sh ${i+1} ${CONTROLLERIPS[$i]}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

