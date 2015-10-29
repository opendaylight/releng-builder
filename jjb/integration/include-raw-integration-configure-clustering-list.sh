#!/bin/bash
#
# Copyright (c) 2015 Brocade Communications Systems, Inc. and others.  All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html
#


echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
JOLOKIACONF=/tmp/${BUNDLEFOLDER}/deploy/jolokia.xml

# Create the list of controllers from the CONTROLLER_LIST variable
ODL_SYSTEM_IPS=( ${ODL_SYSTEM_IP_LIST//,/ } )

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
count=1
for ip in ${ODL_SYSTEM_IPS[@]} ; do
   data_seed_nodes[$count]=\\\"akka.tcp:\\/\\/opendaylight-cluster-data@${ip}:2550\\\"
   rpc_seed_nodes[$count]=\\\"akka.tcp:\\/\\/odl-cluster-rpc@${ip}:2551\\\"
   member_names[$count]=\\\"member-${count}\\\"
   count=$[count + 1]
done
data_seed_list=$(join ${data_seed_nodes[@]})
rpc_seed_list=$(join ${rpc_seed_nodes[@]})
member_name_list=$(join ${member_names[@]})

# echo ${ODL_SYSTEM_IP_LIST}
# echo ${ODL_SYSTEM_IPS[@]}
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
for i in "${!ODL_SYSTEM_IPS[@]}"
do
    echo "Configuring member-$((i+1)) with IP address ${ODL_SYSTEM_IPS[$i]}"
    ssh ${ODL_SYSTEM_IPS[$i]} "mkdir /tmp/${BUNDLEFOLDER}/configuration/initial"
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/openflow/akka.conf.template ${ODL_SYSTEM_IPS[$i]}:${AKKACONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/openflow/modules.conf.template ${ODL_SYSTEM_IPS[$i]}:${MODULESCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/openflow/module-shards.conf.template ${ODL_SYSTEM_IPS[$i]}:${MODULESHARDSCONF}
    scp  ${WORKSPACE}/test/tools/clustering/cluster-deployer/templates/openflow/jolokia.xml.template ${ODL_SYSTEM_IPS[$i]}:${JOLOKIACONF}
    scp  ${WORKSPACE}/configuration-script.sh    ${ODL_SYSTEM_IPS[$i]}:/tmp/
    ssh ${ODL_SYSTEM_IPS[$i]} "bash /tmp/configuration-script.sh $((i+1)) ${ODL_SYSTEM_IPS[$i]}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :

