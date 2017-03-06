#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

# TODO: remove this work to run changes.py if/when it's moved higher up to be visible at the Robot level
echo "showing recent changes that made it in to the distribution used by this job"
pip install --upgrade urllib3
python ${WORKSPACE}/test/tools/distchanges/changes.py -d /tmp/distribution_folder \
                  -u ${ACTUALBUNDLEURL} -b ${DISTROBRANCH} \
                  -r ssh://jenkins-${SILO}@git.opendaylight.org:29418 || true

echo "#################################################"
echo "##         Deploy Openstack 3-node             ##"
echo "#################################################"


SSH="ssh -t -t"

function create_control_node_local_conf {
local_conf_file_name=${WORKSPACE}/local.conf_control
#Needs to be removed
if [ "${ODL_ML2_BRANCH}" != "stable/ocata" ]; then
   RECLONE=no
else
   RECLONE=yes
fi
cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
SCREEN_LOGDIR=/opt/stack/data/log
LOG_COLOR=False
RECLONE=${RECLONE}
EOF

IFS=,
for service_name in ${DISABLE_OS_SERVICES}
do
cat >> ${local_conf_file_name} << EOF
disable_service ${service_name}
EOF
done
for service_name in ${ENABLE_OS_SERVICES}
do
cat >> ${local_conf_file_name} << EOF
enable_service ${service_name}
EOF
done
for plugin_name in ${ENABLE_OS_PLUGINS}
do
if [ "$plugin_name" == "networking-odl" ]; then
    ENABLE_PLUGIN_ARGS="${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}"
elif [ "$plugin_name" == "kuryr-kubernetes" ]; then
    ENABLE_PLUGIN_ARGS="${DEVSTACK_KUBERNETES_PLUGIN_REPO} master" # note: kuryr-kubernetes only exists in master at the moment
elif [ "$plugin_name" == "neutron-lbaas" ]; then
    ENABLE_PLUGIN_ARGS="${DEVSTACK_LBAAS_PLUGIN_REPO} ${OPENSTACK_BRANCH}"
else
    echo "Error: Invalid plugin $plugin_name, unsupported"
    continue
fi
cat >> ${local_conf_file_name} << EOF
enable_plugin ${plugin_name} ${ENABLE_PLUGIN_ARGS}
EOF
done
unset IFS
if [ "${OPENSTACK_BRANCH}" == "master" ] || [ "${OPENSTACK_BRANCH}" == "stable/ocata" ]; then # Ocata+
    # placement is mandatory for nova since Ocata, note that this requires computes to enable placement-client
    # this should be moved into enabled_services for each job (but only for Ocata)
    echo "enable_service placement-api" >> ${local_conf_file_name}
fi
cat >> ${local_conf_file_name} << EOF
HOST_IP=$OPENSTACK_CONTROL_NODE_IP
SERVICE_HOST=\$HOST_IP

NEUTRON_CREATE_INITIAL_NETWORKS=${CREATE_INITIAL_NETWORKS}
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=${TENANT_NETWORK_TYPE}
Q_OVS_USE_VETH=True

ENABLE_TENANT_TUNNELS=True

MYSQL_HOST=\$SERVICE_HOST
RABBIT_HOST=\$SERVICE_HOST
GLANCE_HOSTPORT=\$SERVICE_HOST:9292
KEYSTONE_AUTH_HOST=\$SERVICE_HOST
KEYSTONE_SERVICE_HOST=\$SERVICE_HOST

MYSQL_PASSWORD=mysql
RABBIT_PASSWORD=rabbit
SERVICE_TOKEN=service
SERVICE_PASSWORD=admin
ADMIN_PASSWORD=admin

ODL_PORT=8080
ODL_MODE=externalodl
ODL_PORT_BINDING_CONTROLLER=${ODL_ML2_PORT_BINDING}

LIBVIRT_TYPE=qemu

NEUTRON_LBAAS_SERVICE_PROVIDERV2=${LBAAS_SERVICE_PROVIDER} # Only relevant if neutron-lbaas plugin is enabled
EOF

if [ "${ENABLE_NETWORKING_L2GW}" == "yes" ]; then
cat >> ${local_conf_file_name} << EOF

enable_plugin networking-l2gw ${NETWORKING_L2GW_DRIVER} ${ODL_ML2_BRANCH}
NETWORKING_L2GW_SERVICE_DRIVER=L2GW:OpenDaylight:networking_odl.l2gateway.driver.OpenDaylightL2gwDriver:default
ENABLED_SERVICES+=,neutron,q-svc,nova,q-meta

EOF
fi

if [ "${ODL_ML2_DRIVER_VERSION}" == "v2" ]; then
    echo "ODL_V2DRIVER=True" >> ${local_conf_file_name}
fi

if [ "${NUM_ODL_SYSTEM}" -gt 1 ]; then
odl_list=${ODL_SYSTEM_1_IP}
for i in `seq 2 ${NUM_ODL_SYSTEM}`
do
odlip=ODL_SYSTEM_${i}_IP
odl_list=${odl_list},${!odlip}
done
if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
HA_PROXY_INDEX=${NUM_OPENSTACK_SYSTEM}
odlmgrip=OPENSTACK_COMPUTE_NODE_${HA_PROXY_INDEX}_IP
odl_mgr_ip=${!odlmgrip}
else
odl_mgr_ip=${ODL_SYSTEM_1_IP}
fi
cat >> ${local_conf_file_name} << EOF
ODL_OVS_MANAGERS=${odl_list}
ODL_MGR_IP=${odl_mgr_ip}
EOF
else
cat >> ${local_conf_file_name} << EOF
ODL_MGR_IP=${ODL_SYSTEM_1_IP}
EOF
fi

# if we are using the old netvirt impl, as determined by the feature name
# odl-ovsdb-openstack (note: new impl is odl-netvirt-openstack) then we
# want ODL_L3 to be True.  New impl wants it False
if [[ ${CONTROLLERFEATURES} == *"odl-ovsdb-openstack"* ]]; then
  ODL_L3=True
else
  ODL_L3=False
fi

# if we are using the new netvirt impl, as determined by the feature name
# odl-netvirt-openstack (note: old impl is odl-ovsdb-openstack) then we
# want PROVIDER_MAPPINGS to be used -- this should be fixed if we want to support
# external networks in legacy netvirt
if [[ ${CONTROLLERFEATURES} == *"odl-netvirt-openstack"* ]]; then
  ODL_PROVIDER_MAPPINGS="\${PUBLIC_PHYSICAL_NETWORK}:${PUBLIC_BRIDGE}"
else
  ODL_PROVIDER_MAPPINGS=
fi

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
cat >> ${local_conf_file_name} << EOF
PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ML2_VLAN_RANGES=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}

disable_service q-l3
PUBLIC_INTERFACE=br100
EOF

if [ -z ${DISABLE_ODL_L3_PLUGIN} ] || [ "${DISABLE_ODL_L3_PLUGIN}" == "no" ]; then
if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
cat >> ${local_conf_file_name} << EOF
Q_L3_ENABLED=True
ODL_L3=${ODL_L3}
[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
service_plugins = networking_odl.l3.l3_odl.OpenDaylightL3RouterPlugin

EOF
fi #check for ODL_ML2_BRANCH
fi #check for DISABLE_ODL_L3_PLUGIN

fi #ODL_ENABLE_L3_FWD check

cat >> ${local_conf_file_name} << EOF
[[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
[agent]
minimize_polling=True

[ml2]
# Needed for VLAN provider tests - because our provider networks are always encapsulated in VXLAN (br-phys1)
# MTU(1440) + VXLAN(50) + VLAN(4) = 1494 < MTU eth0/br-phys1(1500)
physical_network_mtus = ${PUBLIC_PHYSICAL_NETWORK}:1440
path_mtu = 1490

[[post-config|/etc/neutron/dhcp_agent.ini]]
[DEFAULT]
force_metadata = True
enable_isolated_metadata = True

[[post-config|/etc/nova/nova.conf]]
[DEFAULT]
force_config_drive = False

EOF

echo "local.conf Created...."
cat ${local_conf_file_name}
}

function create_compute_node_local_conf {
HOSTIP=$1
#Needs to be removed
if [ "${ODL_ML2_BRANCH}" != "stable/ocata" ]; then
   RECLONE=no
else
   RECLONE=yes
fi
if [ "${OPENSTACK_BRANCH}" == "master" ] || [ "${OPENSTACK_BRANCH}" == "stable/ocata" ]; then # Ocata+
    # placement is mandatory for nova since Ocata, note that this requires controller to enable placement-api
    ENABLED_SERVICES="n-cpu,placement-client"
else
    ENABLED_SERVICES="n-cpu"
fi

local_conf_file_name=${WORKSPACE}/local.conf_compute_${HOSTIP}
cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
LOG_COLOR=False
SCREEN_LOGDIR=/opt/stack/data/log
RECLONE=${RECLONE}

NOVA_VNC_ENABLED=True
MULTI_HOST=1
ENABLED_SERVICES=${ENABLED_SERVICES}
HOST_IP=${HOSTIP}
SERVICE_HOST=${OPENSTACK_CONTROL_NODE_IP}

Q_PLUGIN=ml2
ENABLE_TENANT_TUNNELS=True
Q_ML2_TENANT_NETWORK_TYPE=vxlan

Q_HOST=\$SERVICE_HOST
MYSQL_HOST=\$SERVICE_HOST
RABBIT_HOST=\$SERVICE_HOST
GLANCE_HOSTPORT=\$SERVICE_HOST:9292
KEYSTONE_AUTH_HOST=\$SERVICE_HOST
KEYSTONE_SERVICE_HOST=\$SERVICE_HOST

MYSQL_PASSWORD=mysql
RABBIT_PASSWORD=rabbit
SERVICE_TOKEN=service
SERVICE_PASSWORD=admin
ADMIN_PASSWORD=admin

ODL_MODE=compute
ODL_PORT_BINDING_CONTROLLER=${ODL_ML2_PORT_BINDING}
LIBVIRT_TYPE=qemu
EOF

if [[ "${ENABLE_OS_PLUGINS}" =~ networking-odl ]]; then
cat >> ${local_conf_file_name} << EOF
enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}
EOF
fi

if [ "${NUM_ODL_SYSTEM}" -gt 1 ]; then
odl_list=${ODL_SYSTEM_1_IP}
for i in `seq 2 ${NUM_ODL_SYSTEM}`
do
odlip=ODL_SYSTEM_${i}_IP
odl_list=${odl_list},${!odlip}
done
if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
HA_PROXY_INDEX=${NUM_OPENSTACK_SYSTEM}
odlmgrip=OPENSTACK_COMPUTE_NODE_${HA_PROXY_INDEX}_IP
odl_mgr_ip=${!odlmgrip}
else
odl_mgr_ip=${ODL_SYSTEM_1_IP}
fi
cat >> ${local_conf_file_name} << EOF
ODL_OVS_MANAGERS=${odl_list}
ODL_MGR_IP=${odl_mgr_ip}
EOF
else
cat >> ${local_conf_file_name} << EOF
ODL_MGR_IP=${ODL_SYSTEM_1_IP}
EOF
fi

# if we are using the new netvirt impl, as determined by the feature name
# odl-netvirt-openstack (note: old impl is odl-ovsdb-openstack) then we
# want PROVIDER_MAPPINGS to be used -- this should be fixed if we want to support
# external networks in legacy netvirt
if [[ ${CONTROLLERFEATURES} == *"odl-netvirt-openstack"* ]]; then
  ODL_PROVIDER_MAPPINGS="\${PUBLIC_PHYSICAL_NETWORK}:${PUBLIC_BRIDGE}"
else
  ODL_PROVIDER_MAPPINGS=
fi

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
cat >> ${local_conf_file_name} << EOF
# Uncomment lines below if odl-compute is to be used for l3 forwarding
Q_L3_ENABLED=True
ODL_L3=${ODL_L3}
PUBLIC_INTERFACE=br100 # FIXME do we use br100 at all?
PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
EOF
fi
echo "local.conf Created...."
cat ${local_conf_file_name}
}

function configure_haproxy_for_neutron_requests () {
HA_PROXY_INDEX=${NUM_OPENSTACK_SYSTEM}
odlmgrip=OPENSTACK_COMPUTE_NODE_${HA_PROXY_INDEX}_IP
ha_proxy_ip=${!odlmgrip}

cat > ${WORKSPACE}/install_ha_proxy.sh<< EOF
sudo systemctl stop firewalld
sudo yum -y install policycoreutils-python haproxy
EOF

cat > ${WORKSPACE}/haproxy.cfg << EOF
global
  daemon
  group  haproxy
  log  /dev/log local0
  maxconn  20480
  pidfile  /tmp/haproxy.pid
  user  haproxy

defaults
  log  global
  maxconn  4096
  mode  tcp
  retries  3
  timeout  http-request 10s
  timeout  queue 1m
  timeout  connect 10s
  timeout  client 1m
  timeout  server 1m
  timeout  check 10s

listen opendaylight
  bind ${ha_proxy_ip}:8080
  balance source
EOF

for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
odlip=ODL_SYSTEM_${i}_IP
cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-$i ${!odlip}:8080 check fall 5 inter 2000 rise 2
EOF
done

cat >> ${WORKSPACE}/haproxy.cfg << EOF
listen opendaylight_rest
  bind ${ha_proxy_ip}:8181
  balance source
EOF

for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
odlip=ODL_SYSTEM_${i}_IP
cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-rest-$i ${!odlip}:8181 check fall 5 inter 2000 rise 2
EOF
done

cat > ${WORKSPACE}/deploy_ha_proxy.sh<< EOF
sudo chown haproxy:haproxy /tmp/haproxy.cfg
sudo sed -i 's/\\/etc\\/haproxy\\/haproxy.cfg/\\/tmp\\/haproxy.cfg/g' /usr/lib/systemd/system/haproxy.service
sudo /usr/sbin/semanage permissive -a haproxy_t
sudo systemctl restart haproxy
sleep 3
sudo netstat -tunpl
sudo systemctl status haproxy
true
EOF
scp ${WORKSPACE}/install_ha_proxy.sh ${ha_proxy_ip}:/tmp
${SSH} ${ha_proxy_ip} "sudo bash /tmp/install_ha_proxy.sh"
scp ${WORKSPACE}/haproxy.cfg ${ha_proxy_ip}:/tmp
scp ${WORKSPACE}/deploy_ha_proxy.sh ${ha_proxy_ip}:/tmp
${SSH} ${ha_proxy_ip} "sudo bash /tmp/deploy_ha_proxy.sh"
}

function collect_logs_and_exit (){
set +e  # We do not want to create red dot just because something went wrong while fetching logs.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "killing karaf process..."
    ${SSH} "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done

cat > extra_debug.sh << EOF
echo -e "/usr/sbin/lsmod | /usr/bin/grep openvswitch\n"
/usr/sbin/lsmod | /usr/bin/grep openvswitch
echo -e "\ngrep ct_ /var/log/openvswitch/ovs-vswitchd.log\n"
grep ct_ /var/log/openvswitch/ovs-vswitchd.log
EOF

sleep 5
# FIXME: Do not create .tar and gzip before copying.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    ${SSH} "${!CONTROLLERIP}"  "cp -r /tmp/${BUNDLEFOLDER}/data/log /tmp/odl_log"
    ${SSH} "${!CONTROLLERIP}"  "tar -cf /tmp/odl${i}_karaf.log.tar /tmp/odl_log/*"
    scp "${!CONTROLLERIP}:/tmp/odl${i}_karaf.log.tar" "${WORKSPACE}/odl${i}_karaf.log.tar"
    tar -xvf ${WORKSPACE}/odl${i}_karaf.log.tar -C . --strip-components 2 --transform s/karaf/odl${i}_karaf/g
    grep "ROBOT MESSAGE\| ERROR " odl${i}_karaf.log > odl${i}_err.log
    grep "ROBOT MESSAGE\|Exception" odl${i}_karaf.log > odl${i}_exception.log
    grep "ROBOT MESSAGE\| ERROR \| WARN \|Exception" odl${i}_karaf.log > odl${i}_err_warn_exception.log
    rm ${WORKSPACE}/odl${i}_karaf.log.tar
done

# Since this log collection work is happening before the archive build macro which also
# creates the ${WORKSPACE}/archives dir, we have to do it here first.  The mkdir in the
# archives build step will essentially be a noop.
mkdir -p ${WORKSPACE}/archives

# Control Node
OS_CTRL_FOLDER="control"
mkdir -p ${OS_CTRL_FOLDER}
scp ${OPENSTACK_CONTROL_NODE_IP}:/opt/stack/devstack/nohup.out ${OS_CTRL_FOLDER}/stack.log
scp ${OPENSTACK_CONTROL_NODE_IP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_CTRL_FOLDER}/ovs-vswitchd.log
scp ${OPENSTACK_CONTROL_NODE_IP}:/etc/neutron/neutron.conf ${OS_CTRL_FOLDER}/neutron.conf
rsync -avhe ssh ${OPENSTACK_CONTROL_NODE_IP}:/opt/stack/logs/* ${OS_CTRL_FOLDER} # rsync to prevent copying of symbolic links
scp extra_debug.sh ${OPENSTACK_CONTROL_NODE_IP}:/tmp
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
scp ${OPENSTACK_CONTROL_NODE_IP}:/tmp/extra_debug.log ${OS_CTRL_FOLDER}/extra_debug.log
mv local.conf_control ${OS_CTRL_FOLDER}/local.conf
mv ${OS_CTRL_FOLDER} ${WORKSPACE}/archives/

# Compute Nodes
for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    OS_COMPUTE_FOLDER="compute_${i}"
    mkdir -p ${OS_COMPUTE_FOLDER}
    scp ${!OSIP}:/opt/stack/devstack/nohup.out ${OS_COMPUTE_FOLDER}/stack.log
    scp ${!OSIP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_COMPUTE_FOLDER}/ovs-vswitchd.log
    scp ${!OSIP}:/etc/nova/nova.conf ${OS_COMPUTE_FOLDER}/nova.conf
    rsync -avhe ssh ${!OSIP}:/opt/stack/logs/* ${OS_COMPUTE_FOLDER} # rsync to prevent copying of symbolic links
    scp extra_debug.sh ${!OSIP}:/tmp
    ${SSH} ${!OSIP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
    scp ${!OSIP}:/tmp/extra_debug.log ${OS_COMPUTE_FOLDER}/extra_debug.log
    mv local.conf_compute_${!OSIP} ${OS_COMPUTE_FOLDER}/local.conf
    mv ${OS_COMPUTE_FOLDER} ${WORKSPACE}/archives/
done

ls local.conf* | xargs -I % mv % %.log

# Tempest
DEVSTACK_TEMPEST_DIR="/opt/stack/tempest"
if $(ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo sh -c '[ -f ${DEVSTACK_TEMPEST_DIR}/.testrepository/0 ]'"); then # if Tempest results exist
    ssh ${OPENSTACK_CONTROL_NODE_IP} "for I in \$(sudo ls ${DEVSTACK_TEMPEST_DIR}/.testrepository/ | grep -E '^[0-9]+$'); do sudo sh -c \"${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/subunit-1to2 < ${DEVSTACK_TEMPEST_DIR}/.testrepository/\${I} >> ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt\"; done"
    ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo sh -c '${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/python ${DEVSTACK_TEMPEST_DIR}/.tox/tempest/lib/python2.7/site-packages/os_testr/subunit2html.py ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt ${DEVSTACK_TEMPEST_DIR}/tempest_results.html'"
    TEMPEST_LOGS_DIR=${WORKSPACE}/archives/tempest
    mkdir -p ${TEMPEST_LOGS_DIR}
    scp ${OPENSTACK_CONTROL_NODE_IP}:${DEVSTACK_TEMPEST_DIR}/tempest_results.html ${TEMPEST_LOGS_DIR}
    scp ${OPENSTACK_CONTROL_NODE_IP}:${DEVSTACK_TEMPEST_DIR}/tempest.log ${TEMPEST_LOGS_DIR}
    mv ${WORKSPACE}/tempest_output* ${TEMPEST_LOGS_DIR}
fi
}

cat > ${WORKSPACE}/disable_firewall.sh << EOF
sudo systemctl stop firewalld
sudo systemctl stop iptables
true
EOF

cat > ${WORKSPACE}/get_devstack.sh << EOF
sudo systemctl stop firewalld
sudo yum install bridge-utils -y
sudo systemctl stop  NetworkManager
#Disable NetworkManager and kill dhclient and dnsmasq
sudo systemctl stop NetworkManager
sudo killall dhclient
sudo killall dnsmasq
#Workaround for mysql failure
echo "127.0.0.1    localhost \${HOSTNAME}" > /tmp/hosts
echo "::1   localhost  \${HOSTNAME}" >> /tmp/hosts
sudo mv /tmp/hosts /etc/hosts
sudo /usr/sbin/brctl addbr br100
#sudo ifconfig eth0 mtu 2000
sudo mkdir /opt/stack
sudo chmod 777 /opt/stack
cd /opt/stack
git clone https://git.openstack.org/openstack-dev/devstack
cd devstack
git checkout $OPENSTACK_BRANCH
EOF

echo "Create HAProxy if needed"
if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
 echo "Need to configure HAProxy"
 configure_haproxy_for_neutron_requests
fi

os_node_list=()
echo "Stack the Control Node"
scp ${WORKSPACE}/get_devstack.sh ${OPENSTACK_CONTROL_NODE_IP}:/tmp
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "bash /tmp/get_devstack.sh"
create_control_node_local_conf
scp ${WORKSPACE}/local.conf_control ${OPENSTACK_CONTROL_NODE_IP}:/opt/stack/devstack/local.conf

cat > "${WORKSPACE}/manual_install_package.sh" << EOF
cd /opt/stack
git clone "\$1"
cd "\$2"
git checkout "\$3"
sudo python setup.py install

EOF


# Workworund for successful stacking with  Mitaka
if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then

  # Workaround for problems with latest versions/specified versions in requirements of openstack
  # Openstacksdk,libvirt-python -> the current version does not work with  Mitaka diue to some requirements
  # conflict and breaks when trying to stack
  # paramiko -> Problems with tempest tests due to paramiko incompatibility with pycrypto.
  # the problem has been solved with  version 1.17. If the latest version of paramiko is used, it causes
  # other timeout problems
  ssh ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/mitaka; sed -i /openstacksdk/d upper-constraints.txt; sed -i /libvirt-python/d upper-constraints.txt; sed -i /paramiko/d upper-constraints.txt"
  scp "${WORKSPACE}/manual_install_package.sh"  "${OPENSTACK_CONTROL_NODE_IP}:/tmp"
  ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo pip install deprecation"
  # Fix for recent requirements update  in the  master branch of the sdk.The section must be replaced with a better fix.
  ssh "${OPENSTACK_CONTROL_NODE_IP}" "sh /tmp/manual_install_package.sh https://github.com/openstack/python-openstacksdk python-openstacksdk 0.9.14"
  ssh "${OPENSTACK_CONTROL_NODE_IP}" "sh /tmp/manual_install_package.sh https://github.com/paramiko/paramiko paramiko 1.17"
fi

ssh ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
ssh ${OPENSTACK_CONTROL_NODE_IP} "ps -ef | grep stack.sh"
ssh ${OPENSTACK_CONTROL_NODE_IP} "ls -lrt /opt/stack/devstack/nohup.out"
os_node_list+=(${OPENSTACK_CONTROL_NODE_IP})

#Workaround for stable/newton jobs
if [ "${ODL_ML2_BRANCH}" == "stable/newton" ]; then
  ssh ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/newton; sed -i /appdirs/d upper-constraints.txt"
fi

for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    COMPUTEIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
    ${SSH} ${!COMPUTEIP} "bash /tmp/get_devstack.sh"
    create_compute_node_local_conf ${!COMPUTEIP}
    scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
    if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
       ssh ${!COMPUTEIP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/mitaka; sed -i /libvirt-python/d upper-constraints.txt"
    fi
    ssh ${!COMPUTEIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
    ssh ${!COMPUTEIP} "ps -ef | grep stack.sh"
    os_node_list+=(${!COMPUTEIP})
done

cat > ${WORKSPACE}/check_stacking.sh << EOF
> /tmp/stack_progress
ps -ef | grep "stack.sh" | grep -v grep
ret=\$?
if [ \${ret} -eq 1 ]; then
  grep "This is your host IP address:" /opt/stack/devstack/nohup.out
  if [ \$? -eq 0 ]; then
     echo "Stacking Complete" > /tmp/stack_progress
  else
     echo "Stacking Failed" > /tmp/stack_progress
  fi
elif [ \${ret} -eq 0 ]; then
  echo "Still Stacking" > /tmp/stack_progress
fi
EOF

#the checking is repeated for an hour
iteration=0
in_progress=1
while [ ${in_progress} -eq 1 ]; do
iteration=$(($iteration + 1))
for index in ${!os_node_list[@]}
do
echo "Check the status of stacking in ${os_node_list[index]}"
scp ${WORKSPACE}/check_stacking.sh  ${os_node_list[index]}:/tmp
${SSH} ${os_node_list[index]} "bash /tmp/check_stacking.sh"
scp ${os_node_list[index]}:/tmp/stack_progress .
#debug
cat stack_progress
stacking_status=`cat stack_progress`
if [ "$stacking_status" == "Still Stacking" ]; then
  continue
elif [ "$stacking_status" == "Stacking Failed" ]; then
  collect_logs_and_exit
  exit 1
elif [ "$stacking_status" == "Stacking Complete" ]; then
  unset os_node_list[index]
  if  [ ${#os_node_list[@]} -eq 0 ]; then
     in_progress=0
  fi
fi
done
 echo "sleep for a minute before the next check"
 sleep 60
 if [ ${iteration} -eq 60 ]; then
  collect_logs_and_exit
  exit 1
 fi
done

#Need to disable firewalld and iptables in control node
echo "Stop Firewall in Control Node for compute nodes to be able to reach the ports and add to hypervisor-list"
scp ${WORKSPACE}/disable_firewall.sh ${OPENSTACK_CONTROL_NODE_IP}:/tmp
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo bash /tmp/disable_firewall.sh"
echo "sleep for a minute and print hypervisor-list"
sleep 60
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack/devstack; source openrc admin admin; nova hypervisor-list"
# in the case that we are doing openstack (control + compute) all in one node, then the number of hypervisors
# will be the same as the number of openstack systems. However, if we are doing multinode openstack then the
# assumption is we have a single control node and the rest are compute nodes, so the number of expected hypervisors
# is one less than the total number of openstack systems
if [ "${NUM_OPENSTACK_SYSTEM}" -eq 1 ]; then
  expected_num_hypervisors=1
else
  expected_num_hypervisors=$((NUM_OPENSTACK_SYSTEM - 1))
fi
num_hypervisors=$(${SSH} ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack/devstack; source openrc admin admin; openstack hypervisor list -f value | wc -l" | tail -1 | tr -d "\r")
if ! [ "${num_hypervisors}" ] || ! [ ${num_hypervisors} -eq ${expected_num_hypervisors} ]; then
  echo "Error: Only $num_hypervisors hypervisors detected, expected $expected_num_hypervisors"
  collect_logs_and_exit
  exit 1
fi

#Need to disable firewalld and iptables in compute nodes as well
for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    scp ${WORKSPACE}/disable_firewall.sh "${!OSIP}:/tmp"
    ${SSH} "${!OSIP}" "sudo bash /tmp/disable_firewall.sh"
done

# upgrading pip, urllib3 and httplib2 so that tempest tests can be run on ${OPENSTACK_CONTROL_NODE_IP}
# this needs to happen after devstack runs because it seems devstack is pulling in specific versions
# of these libs that are not working for tempest.
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo pip install --upgrade pip"
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo pip install urllib3 --upgrade"
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo pip install httplib2 --upgrade"

for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    IP_VAR=OPENSTACK_COMPUTE_NODE_${i}_IP
    COMPUTE_IPS[$((i-1))]=${!IP_VAR}
done

# External Network
echo "prepare external networks by adding vxlan tunnels between all nodes on a separate bridge..."
devstack_index=1
for ip in ${OPENSTACK_CONTROL_NODE_IP} ${COMPUTE_IPS[*]}
do
    # FIXME - Workaround, ODL (new netvirt) currently adds PUBLIC_BRIDGE as a port in br-int since it doesn't see such a bridge existing when we stack
    ${SSH} $ip "sudo ovs-vsctl --if-exists del-port br-int $PUBLIC_BRIDGE"
    ${SSH} $ip "sudo ovs-vsctl --may-exist add-br $PUBLIC_BRIDGE -- set bridge $PUBLIC_BRIDGE other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:0$((devstack_index++))"
done

# ipsec support
if [ "${IPSEC_VXLAN_TUNNELS_ENABLED}" == "yes" ]; then
    ALL_NODES=(${OPENSTACK_CONTROL_NODE_IP} ${COMPUTE_IPS[*]})
    for ((inx_ip1=0; inx_ip1<$((${#ALL_NODES[@]} - 1)); inx_ip1++))
    do
        for ((inx_ip2=$((inx_ip1 + 1)); inx_ip2<${#ALL_NODES[@]}; inx_ip2++))
        do
            KEY1=0x$(dd if=/dev/urandom count=32 bs=1 2> /dev/null| xxd -p -c 64)
            KEY2=0x$(dd if=/dev/urandom count=32 bs=1 2> /dev/null| xxd -p -c 64)
            ID=0x$(dd if=/dev/urandom count=4 bs=1 2> /dev/null| xxd -p -c 8)
            ip1=${ALL_NODES[$inx_ip1]}
            ip2=${ALL_NODES[$inx_ip2]}
            ${SSH} $ip1 "sudo ip xfrm state add src $ip1 dst $ip2 proto esp spi $ID reqid $ID mode transport auth sha256 $KEY1 enc aes $KEY2"
            ${SSH} $ip1 "sudo ip xfrm state add src $ip2 dst $ip1 proto esp spi $ID reqid $ID mode transport auth sha256 $KEY1 enc aes $KEY2"
            ${SSH} $ip1 "sudo ip xfrm policy add src $ip1 dst $ip2 proto udp dir out tmpl src $ip1 dst $ip2 proto esp reqid $ID mode transport"
            ${SSH} $ip1 "sudo ip xfrm policy add src $ip2 dst $ip1 proto udp dir in tmpl src $ip2 dst $ip1 proto esp reqid $ID mode transport"

            ${SSH} $ip2 "sudo ip xfrm state add src $ip2 dst $ip1 proto esp spi $ID reqid $ID mode transport auth sha256 $KEY1 enc aes $KEY2"
            ${SSH} $ip2 "sudo ip xfrm state add src $ip1 dst $ip2 proto esp spi $ID reqid $ID mode transport auth sha256 $KEY1 enc aes $KEY2"
            ${SSH} $ip2 "sudo ip xfrm policy add src $ip2 dst $ip1 proto udp dir out tmpl src $ip2 dst $ip1 proto esp reqid $ID mode transport"
            ${SSH} $ip2 "sudo ip xfrm policy add src $ip1 dst $ip2 proto udp dir in tmpl src $ip1 dst $ip2 proto esp reqid $ID mode transport"
        done
    done
fi

for ip in ${OPENSTACK_CONTROL_NODE_IP} ${COMPUTE_IPS[*]}
do
    echo "ip xfrm configuration for node $ip:"
    ${SSH} $ip "sudo ip xfrm policy list"
    ${SSH} $ip "sudo ip xfrm state list"
done

# Control Node - PUBLIC_BRIDGE will act as the external router
GATEWAY_IP="10.10.10.250" # FIXME this should be a parameter, also shared with integration-test
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo ip link add link ${PUBLIC_BRIDGE} name  ${PUBLIC_BRIDGE}.167 type vlan id 167"
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo ifconfig  ${PUBLIC_BRIDGE} up"
${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo ifconfig   ${PUBLIC_BRIDGE}.167 up ${GATEWAY_IP}/24"
compute_index=1
for compute_ip in ${COMPUTE_IPS[*]}
do
    # Tunnel from controller to compute
    PORT_NAME=compute$((compute_index++))_vxlan
    ${SSH} ${OPENSTACK_CONTROL_NODE_IP} "sudo ovs-vsctl add-port $PUBLIC_BRIDGE $PORT_NAME -- set interface $PORT_NAME type=vxlan options:local_ip="${OPENSTACK_CONTROL_NODE_IP}" options:remote_ip="$compute_ip" options:dst_port=9876 options:key=flow"

    # Tunnel from compute to controller
    PORT_NAME=control_vxlan
    ${SSH} ${compute_ip} "sudo ovs-vsctl add-port $PUBLIC_BRIDGE $PORT_NAME -- set interface $PORT_NAME type=vxlan options:local_ip="$compute_ip" options:remote_ip="${OPENSTACK_CONTROL_NODE_IP}" options:dst_port=9876 options:key=flow"
done

if [ "${NUM_ODL_SYSTEM}" -gt 1 ]; then
  HA_PROXY_INDEX=${NUM_OPENSTACK_SYSTEM}
  odlmgrip=OPENSTACK_COMPUTE_NODE_${HA_PROXY_INDEX}_IP
  HA_PROXY_IP=${!odlmgrip}
else
  HA_PROXY_IP=${ODL_SYSTEM_IP}
fi
echo "Locating test plan to use..."
testplan_filepath="${WORKSPACE}/test/csit/testplans/${STREAMTESTPLAN}"
if [ ! -f "${testplan_filepath}" ]; then
    testplan_filepath="${WORKSPACE}/test/csit/testplans/${TESTPLAN}"
fi

echo "Changing the testplan path..."
cat "${testplan_filepath}" | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`

echo "Starting Robot test suites ${SUITES} ..."
# please add pybot -v arguments on a single line and alphabetized
pybot -N ${TESTPLAN} --removekeywords wuks -c critical -e exclude \
    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
    -v BUNDLE_URL:${ACTUALBUNDLEURL} \
    -v CONTROLLER_USER:${USER} \
    -v DEVSTACK_DEPLOY_PATH:/opt/stack/devstack \
    -v HA_PROXY_IP:${HA_PROXY_IP} \
    -v JDKVERSION:${JDKVERSION} \
    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
    -v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} \
    -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
    -v ODL_STREAM:${DISTROSTREAM} \
    -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
    -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} \
    -v ODL_SYSTEM_2_IP:${ODL_SYSTEM_2_IP} \
    -v ODL_SYSTEM_3_IP:${ODL_SYSTEM_3_IP} \
    -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_IP} \
    -v OPENSTACK_BRANCH:${OPENSTACK_BRANCH} \
    -v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} \
    -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
    -v OS_USER:${USER} \
    -v PUBLIC_PHYSICAL_NETWORK:${PUBLIC_PHYSICAL_NETWORK} \
    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
    -v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_1_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} \
    -v USER_HOME:${HOME} \
    -v WORKSPACE:/tmp \
    ${TESTOPTIONS} ${SUITES} || true

echo "Examining the files in data/log and checking filesize"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
collect_logs_and_exit

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
