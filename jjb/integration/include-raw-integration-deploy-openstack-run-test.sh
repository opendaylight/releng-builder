#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

echo "#################################################"
echo "##         Deploy Openstack 3-node             ##"
echo "#################################################"


SSH="ssh -t -t"

function create_control_node_local_conf {
HOSTIP=$1
MGRIP=$2
OVSLIST="$3"
#Needs to be removed
if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
   RECLONE=no
else
   RECLONE=yes
fi
local_conf_file_name=${WORKSPACE}/local.conf_control_${HOSTIP}
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
unset IFS

cat >> ${local_conf_file_name} << EOF
HOST_IP=${HOSTIP}
SERVICE_HOST=\$HOST_IP

NEUTRON_CREATE_INITIAL_NETWORKS=False
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

enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}

ODL_PORT=8080
ODL_MODE=externalodl
LIBVIRT_TYPE=qemu
ODL_MGR_IP=${MGRIP}

EOF


if [ "${ODL_ML2_DRIVER_VERSION}" == "v2" ]; then
    echo "ODL_V2DRIVER=True" >> ${local_conf_file_name}
fi

if [ "$(( ${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES} ))" -gt 1 ]; then
        echo "ODL_OVS_MANAGERS=${OVSLIST}" >> ${local_conf_file_name}
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
PUBLIC_PHYSICAL_NETWORK=physnet1 # FIXME this should be a parameter
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}

disable_service q-l3
Q_L3_ENABLED=True
ODL_L3=${ODL_L3}
PUBLIC_INTERFACE=br100
EOF

if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
cat >> ${local_conf_file_name} << EOF
[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
service_plugins = networking_odl.l3.l3_odl.OpenDaylightL3RouterPlugin

EOF
fi #check for ODL_ML2_BRANCH

fi #ODL_ENABLE_L3_FWD check

cat >> ${local_conf_file_name} << EOF
[[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
[agent]
minimize_polling=True

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
SERVICEHOST=$2
MGRIP=$3
OVSLIST="$4"
#Needs to be removed
if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
   RECLONE=no
else
   RECLONE=yes
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
ENABLED_SERVICES=n-cpu

HOST_IP=${HOSTIP}
SERVICE_HOST=${SERVICEHOST}

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

enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}
ODL_MODE=compute
LIBVIRT_TYPE=qemu
ODL_MGR_IP=${MGRIP}

EOF

if [ "$(( ${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES} ))" -gt 1 ]; then
    echo "ODL_OVS_MANAGERS=${OVSLIST}" >> ${local_conf_file_name}
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
PUBLIC_PHYSICAL_NETWORK=physnet1 # FIXME this should be a parameter
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
EOF
fi
echo "local.conf Created...."
cat ${local_conf_file_name}
}

function configure_haproxy_for_neutron_requests () {
MGRIP=$1
OVSLIST=(${2//,/ })

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
  bind ${MGRIP}:8080
  balance source
EOF

odlindex=1
for odlip in ${OVSLIST[*]}
do
cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-$((odlindex++)) ${odlip}:8080 check fall 5 inter 2000 rise 2
EOF
done

cat >> ${WORKSPACE}/haproxy.cfg << EOF
listen opendaylight_rest
  bind ${MGRIP}:8181
  balance source
EOF

odlindex=1
for odlip in ${OVSLIST[*]}
do
cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-rest-$((odlindex++)) ${odlip}:8181 check fall 5 inter 2000 rise 2
EOF
done

echo "Dump haproxy.cfg"
cat ${WORKSPACE}/haproxy.cfg

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
scp ${WORKSPACE}/install_ha_proxy.sh ${MGRIP}:/tmp
${SSH} ${MGRIP} "sudo bash /tmp/install_ha_proxy.sh"
scp ${WORKSPACE}/haproxy.cfg ${MGRIP}:/tmp
scp ${WORKSPACE}/deploy_ha_proxy.sh ${MGRIP}:/tmp
${SSH} ${MGRIP} "sudo bash /tmp/deploy_ha_proxy.sh"
}

function collect_logs_and_exit () {
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
    rm ${WORKSPACE}/odl${i}_karaf.log.tar
done

# Since this log collection work is happening before the archive build macro which also
# creates the ${WORKSPACE}/archives dir, we have to do it here first.  The mkdir in the
# archives build step will essentially be a noop.
mkdir -p ${WORKSPACE}/archives

# Control Node
for i in `seq 1 ${NUM_OPENSTACK_SITES}`
do
    OS_CTRL_IP=OPENSTACK_CONTROL_NODE_${i}_IP
    OS_CTRL_FOLDER="control_${i}"
    mkdir -p ${OS_CTRL_FOLDER}
    scp ${!OS_CTRL_IP}:/opt/stack/devstack/nohup.out ${OS_CTRL_FOLDER}/stack.log
    scp ${!OS_CTRL_IP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_CTRL_FOLDER}/ovs-vswitchd.log
    rsync -avhe ssh ${!OS_CTRL_IP}:/opt/stack/logs/* ${OS_CTRL_FOLDER} # rsync to prevent copying of symbolic links
    scp extra_debug.sh ${!OS_CTRL_IP}:/tmp
    ${SSH} ${!OS_CTRL_IP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
    scp ${!OS_CTRL_IP}:/tmp/extra_debug.log ${OS_CTRL_FOLDER}/extra_debug.log
    mv local.conf_control ${OS_CTRL_FOLDER}/local.conf
    mv ${OS_CTRL_FOLDER} ${WORKSPACE}/archives/
done

# Compute Nodes
for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    OS_COMPUTE_FOLDER="compute_${i}"
    mkdir -p ${OS_COMPUTE_FOLDER}
    scp ${!OSIP}:/opt/stack/devstack/nohup.out ${OS_COMPUTE_FOLDER}/stack.log
    scp ${!OSIP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_COMPUTE_FOLDER}/ovs-vswitchd.log
    rsync -avhe ssh ${!OSIP}:/opt/stack/logs/* ${OS_COMPUTE_FOLDER} # rsync to prevent copying of symbolic links
    scp extra_debug.sh ${!OSIP}:/tmp
    ${SSH} ${!OSIP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
    scp ${!OSIP}:/tmp/extra_debug.log ${OS_COMPUTE_FOLDER}/extra_debug.log
    mv local.conf_compute_${!OSIP} ${OS_COMPUTE_FOLDER}/local.conf
    mv ${OS_COMPUTE_FOLDER} ${WORKSPACE}/archives/
done

ls local.conf* | xargs -I % mv % %.log
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

control_index=1
compute_index=1
odl_index=1
os_node_list=()
os_interval=$(( ${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES} ))
ha_proxy_index=${os_interval}

for i in `seq 1 ${NUM_OPENSTACK_SYSTEM}`
do
    if [ $(( $i % (${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
        echo "Generate odl ovs list"
        ODLIP=ODL_SYSTEM_${odl_index}_IP
        ODLMGRIP=${!ODLIP}
        ODLOVSLIST=${!ODLIP}
            if [ $(( $odl_index % (${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
                while [ $odl_index -le ${NUM_ODL_SYSTEM} ]
                do
                    if [ $(( (odl_index+1) % (${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
                        break
                    fi
                    ODLIP=ODL_SYSTEM_$(( ++odl_index ))_IP
                    ODLOVSLIST="${ODLOVSLIST},${!ODLIP}"
                done
            fi
        odl_index=$((odl_index+1))
        echo ${ODLOVSLIST}
    fi

    if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ] && [ $(( $i % (${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 0 ]; then
        echo "Configure HAProxy"
        ODLMGRIP=OPENSTACK_COMPUTE_NODE_${ha_proxy_index}_IP
        ha_proxy_index=$(( $ha_proxy_index + $os_interval ))
        configure_haproxy_for_neutron_requests ${!ODLMGRIP} "${ODLOVSLIST}"
        continue
    fi

    if [ $(( $i % (${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
        echo "Stack the Control Node"
        CONTROLIP=OPENSTACK_CONTROL_NODE_$(( control_index++ ))_IP
        scp ${WORKSPACE}/get_devstack.sh ${!CONTROLIP}:/tmp
        ${SSH} ${!CONTROLIP} "bash /tmp/get_devstack.sh"
        create_control_node_local_conf ${!CONTROLIP} ${!ODLMGRIP} "${ODLOVSLIST}"
        scp ${WORKSPACE}/local.conf_control_${!CONTROLIP} ${!CONTROLIP}:/opt/stack/devstack/local.conf
            if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
                ssh ${!CONTROLIP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/mitaka; sed -i /openstacksdk/d upper-constraints.txt; sed -i /libvirt-python/d upper-constraints.txt"
                ssh ${!CONTROLIP} "cd /opt/stack; git clone https://github.com/openstack/python-openstacksdk; cd python-openstacksdk; sudo python setup.py install"
            fi
        ssh ${!CONTROLIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
        ssh ${!CONTROLIP} "ps -ef | grep stack.sh"
        ssh ${!CONTROLIP} "ls -lrt /opt/stack/devstack/nohup.out"
        os_node_list+=(${!CONTROLIP})

    else

        echo "Stack the Compute Node"
        COMPUTEIP=OPENSTACK_COMPUTE_NODE_$(( compute_index++ ))_IP
        scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
        ${SSH} ${!COMPUTEIP} "bash /tmp/get_devstack.sh"
        create_compute_node_local_conf ${!COMPUTEIP} ${!CONTROLIP} ${!ODLMGRIP} "${ODLOVSLIST}"
        scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
        if [ "${ODL_ML2_BRANCH}" == "stable/mitaka" ]; then
            ssh ${!COMPUTEIP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/mitaka; sed -i /libvirt-python/d upper-constraints.txt"
        fi
        ssh ${!COMPUTEIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
        ssh ${!COMPUTEIP} "ps -ef | grep stack.sh"
        os_node_list+=(${!COMPUTEIP})

    fi
done

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

control_index=1
compute_index=1
devstack_index=1
for i in `seq 1 ${NUM_OPENSTACK_SYSTEM}`
do
    # skip ha proxy machine
    if ([ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ] && [ $(( $i % (${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 0 ]); then
        continue
    fi
    if [ $(( $i % (${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
        echo "Configure the Control Node"
        CONTROLIP=OPENSTACK_CONTROL_NODE_${control_index}_IP
        CONTROLPORT=control$(( control_index++ ))_vxlan
        #Need to disable firewalld and iptables in control node
        echo "Stop Firewall in Control Node for compute nodes to be able to reach the ports and add to hypervisor-list"
        scp ${WORKSPACE}/disable_firewall.sh ${!CONTROLIP}:/tmp
        ${SSH} ${!CONTROLIP} "sudo bash /tmp/disable_firewall.sh"
        echo "sleep for a minute and print hypervisor-list"
        sleep 60
        ${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; nova hypervisor-list"
        # in the case that we are doing openstack (control + compute) all in one node, then the number of hypervisors
        # will be the same as the number of openstack systems. However, if we are doing multinode openstack then the
        # assumption is we have a single control node and the rest are compute nodes, so the number of expected hypervisors
        # is one less than the total number of openstack systems
        if [ $((NUM_OPENSTACK_SYSTEM / NUM_OPENSTACK_SITES - 1)) -eq 1 ]; then
            expected_num_hypervisors=1
        else
            expected_num_hypervisors=$((NUM_OPENSTACK_SYSTEM / NUM_OPENSTACK_SITES - 1))
        fi

        num_hypervisors=$(${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; openstack hypervisor list -f value | wc -l" | tail -1 | tr -d "\r")
        if ! [ "${num_hypervisors}" ] || ! [ ${num_hypervisors} -eq ${expected_num_hypervisors} ]; then
            echo "Error: Only $num_hypervisors hypervisors detected, expected $expected_num_hypervisors"
            collect_logs_and_exit
            exit 1
        fi
        # upgrading pip, urllib3 and httplib2 so that tempest tests can be run on openstack control node
        # this needs to happen after devstack runs because it seems devstack is pulling in specific versions
        # of these libs that are not working for tempest.
        ${SSH} ${!CONTROLIP} "sudo pip install --upgrade pip"
        ${SSH} ${!CONTROLIP} "sudo pip install urllib3 --upgrade"
        ${SSH} ${!CONTROLIP} "sudo pip install httplib2 --upgrade"
        # External Network
        echo "prepare external networks by adding vxlan tunnels between all nodes on a separate bridge..."
        # FIXME - Workaround, ODL (new netvirt) currently adds PUBLIC_BRIDGE as a port in br-int since it doesn't see such a bridge existing when we stack
        ${SSH} ${!CONTROLIP} "sudo ovs-vsctl --if-exists del-port br-int $PUBLIC_BRIDGE"
        ${SSH} ${!CONTROLIP} "sudo ovs-vsctl --may-exist add-br $PUBLIC_BRIDGE -- set bridge $PUBLIC_BRIDGE other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:0$((devstack_index++))"
        # Control Node - PUBLIC_BRIDGE will act as the external router
        GATEWAY_IP="10.10.10.250" # FIXME this should be a parameter, also shared with integration-test
        ${SSH} ${!CONTROLIP} "sudo ifconfig $PUBLIC_BRIDGE up ${GATEWAY_IP}/24"

    else

        echo "Configure the Compute Node"
        COMPUTEIP=OPENSTACK_COMPUTE_NODE_${compute_index}_IP
        COMPUTEPORT=compute$(( compute_index++ ))_vxlan
        #Need to disable firewalld and iptables in compute nodes as well
        scp ${WORKSPACE}/disable_firewall.sh "${!COMPUTEIP}:/tmp"
        ${SSH} ${!COMPUTEIP} "sudo bash /tmp/disable_firewall.sh"
        echo "prepare external networks by adding vxlan tunnels between all nodes on a separate bridge..."
        # FIXME - Workaround, ODL (new netvirt) currently adds PUBLIC_BRIDGE as a port in br-int since it doesn't see such a bridge existing when we stack
        ${SSH} ${!COMPUTEIP} "sudo ovs-vsctl --if-exists del-port br-int $PUBLIC_BRIDGE"
        ${SSH} ${!COMPUTEIP} "sudo ovs-vsctl --may-exist add-br $PUBLIC_BRIDGE -- set bridge $PUBLIC_BRIDGE other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:0$((devstack_index++))"
        # Tunnel from controller to compute
        ${SSH} ${!CONTROLIP} "sudo ovs-vsctl add-port $PUBLIC_BRIDGE $COMPUTEPORT -- set interface $COMPUTEPORT type=vxlan options:local_ip="${!CONTROLIP}" options:remote_ip="${!COMPUTEIP}" options:dst_port=9876 options:key=flow"
        # Tunnel from compute to controller
        ${SSH} ${!COMPUTEIP} "sudo ovs-vsctl add-port $PUBLIC_BRIDGE $CONTROLPORT -- set interface $CONTROLPORT type=vxlan options:local_ip="${!COMPUTEIP}" options:remote_ip="${!CONTROLIP}" options:dst_port=9876 options:key=flow"

    fi
done

#FIXME currently support only 1 site
if [ $(( ${NUM_ODL_SYSTEM} / ${NUM_OPENSTACK_SITES} )) -gt 1 ]; then
  HA_PROXY_INDEX=$((NUM_OPENSTACK_SYSTEM / NUM_OPENSTACK_SITES))
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

#FIXME currently support only 1 site
echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} --removekeywords wuks -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v BUNDLE_URL:${ACTUALBUNDLEURL} -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v JDKVERSION:${JDKVERSION} -v ODL_STREAM:${DISTROSTREAM} \
-v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} -v ODL_SYSTEM_2_IP:${ODL_SYSTEM_2_IP} \
-v ODL_SYSTEM_3_IP:${ODL_SYSTEM_3_IP} -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} -v CONTROLLER_USER:${USER} -v OS_USER:${USER} \
-v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_IP} \
-v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
-v HA_PROXY_IP:${HA_PROXY_IP} \
-v DEVSTACK_DEPLOY_PATH:/opt/stack/devstack -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

#FIXME currently support only 1 site
echo "Tests Executed"
DEVSTACK_TEMPEST_DIR="/opt/stack/tempest"
if $(ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo sh -c '[ -f ${DEVSTACK_TEMPEST_DIR}/.testrepository/0 ]'"); then # if Tempest results exist
    ssh ${OPENSTACK_CONTROL_NODE_IP} "for I in \$(sudo ls ${DEVSTACK_TEMPEST_DIR}/.testrepository/ | grep -E '^[0-9]+$'); do sudo sh -c \"${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/subunit-1to2 < ${DEVSTACK_TEMPEST_DIR}/.testrepository/\${I} >> ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt\"; done"
    ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo sh -c '${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/python ${DEVSTACK_TEMPEST_DIR}/.tox/tempest/lib/python2.7/site-packages/os_testr/subunit2html.py ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt ${DEVSTACK_TEMPEST_DIR}/tempest_results.html'"
    scp ${OPENSTACK_CONTROL_NODE_IP}:${DEVSTACK_TEMPEST_DIR}/tempest_results.html ${WORKSPACE}/
fi
collect_logs_and_exit

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
