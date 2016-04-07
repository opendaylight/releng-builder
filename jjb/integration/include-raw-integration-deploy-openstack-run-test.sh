#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

echo "#################################################"
echo "##         Deploy Openstack 3-node             ##"
echo "#################################################"

function create_control_node_local_conf {
local_conf_file_name=${WORKSPACE}/local.conf_control
cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
SCREEN_LOGDIR=/opt/stack/data/log
LOG_COLOR=False
RECLONE=yes

disable_service swift
disable_service cinder
disable_service n-net
disable_service q-vpn
enable_service q-svc
enable_service q-dhcp
enable_service q-meta
enable_service tempest
enable_service n-novnc
enable_service n-cauth

HOST_IP=$OPENSTACK_CONTROL_NODE_IP
SERVICE_HOST=\$HOST_IP

NEUTRON_CREATE_INITIAL_NETWORKS=False
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=vxlan

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

ODL_MGR_IP=${ODL_SYSTEM_1_IP}
ODL_PORT=8080
ODL_MODE=externalodl

[[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
[agent]
minimize_polling=True
EOF

if [ "${NUM_ODL_SYSTEM}" -eq 3 ]; then
cat >> ${local_conf_file_name} << EOF
ODL_OVS_MANAGERS=${ODL_SYSTEM_1_IP},${ODL_SYSTEM_2_IP},${ODL_SYSTEM_3_IP}
EOF
fi

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
cat >> ${local_conf_file_name} << EOF

ODL_PROVIDER_MAPPINGS=br-ex:br100

disable_service q-l3
Q_L3_ENABLED=True
ODL_L3=True
PUBLIC_INTERFACE=br100
[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
service_plugins = networking_odl.l3.l3_odl.OpenDaylightL3RouterPlugin

EOF

fi
}

function create_compute_node_local_conf {
HOSTIP=$1
local_conf_file_name=${WORKSPACE}/local.conf_compute_${HOSTIP}
cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
LOG_COLOR=False
SCREEN_LOGDIR=/opt/stack/data/log
RECLONE=yes

NOVA_VNC_ENABLED=True
MULTI_HOST=1
ENABLED_SERVICES=n-cpu

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

enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}
ODL_MODE=compute
ODL_MGR_IP=${ODL_SYSTEM_1_IP}

EOF

if [ "${NUM_ODL_SYSTEM}" -eq 3 ]; then
cat >> ${local_conf_file_name} << EOF
ODL_OVS_MANAGERS=${ODL_SYSTEM_1_IP},${ODL_SYSTEM_2_IP},${ODL_SYSTEM_3_IP}
EOF
fi

if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
cat >> ${local_conf_file_name} << EOF
# Uncomment lines below if odl-compute is to be used for l3 forwarding
Q_L3_ENABLED=True
ODL_L3=True
PUBLIC_INTERFACE=br100

EOF
fi
}

cat > ${WORKSPACE}/get_devstack.sh << EOF
sudo systemctl stop firewalld
#Workaround for mysql failure
echo "127.0.0.1    localhost \${HOSTNAME}" > /tmp/hosts
echo "::1   localhost  \${HOSTNAME}" >> /tmp/hosts
sudo mv /tmp/hosts /etc/hosts
sudo brctl addbr br100
sudo mkdir /opt/stack
sudo chmod 777 /opt/stack
cd /opt/stack
git clone https://git.openstack.org/openstack-dev/devstack
cd devstack
git checkout $OPENSTACK_BRANCH

EOF

echo "Stack the Control Node"
scp ${WORKSPACE}/get_devstack.sh ${OPENSTACK_CONTROL_NODE_IP}:/tmp
ssh ${OPENSTACK_CONTROL_NODE_IP} "bash /tmp/get_devstack.sh"
create_control_node_local_conf
scp ${WORKSPACE}/local.conf_control ${OPENSTACK_CONTROL_NODE_IP}:/opt/stack/devstack/local.conf
ssh ${OPENSTACK_CONTROL_NODE_IP} "cd /opt/stack/devstack; nohup ./stack.sh"
ssh ${OPENSTACK_CONTROL_NODE_IP} "sudo ovs-vsctl show"


for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))`
do
    COMPUTEIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
    ssh ${!COMPUTEIP} "bash /tmp/get_devstack.sh"
    create_compute_node_local_conf ${!COMPUTEIP}
    scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
    ssh ${!COMPUTEIP} "cd /opt/stack/devstack; nohup ./stack.sh"
    ssh ${!COMPUTEIP} "sudo ovs-vsctl show"
done


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
#pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp -v BUNDLE_URL:${ACTUALBUNDLEURL} \
#-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v JDKVERSION:${JDKVERSION} -v ODL_STREAM:${DISTROSTREAM} \
#-v CONTROLLER:${ODL_SYSTEM_IP} -v CONTROLLER1:${ODL_SYSTEM_2_IP} -v CONTROLLER2:${ODL_SYSTEM_3_IP} -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
#${odl_variables} -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} -v CONTROLLER_USER:${USER} -v ODL_SYSTEM_USER:${USER} -v \
#TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_IP} ${tools_variables} -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} -v TOOLS_SYSTEM_USER:${USER} \
#-v MININET:${TOOLS_SYSTEM_IP} -v MININET1:${TOOLS_SYSTEM_2_IP} -v MININET2:${TOOLS_SYSTEM_3_IP} -v MININET_USER:${USER} \
#-v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true
# FIXME: Sort (at least -v) options alphabetically.

set +e  # We do not want to create red dot just because something went wrong while fetching logs.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "dumping first 500K bytes of karaf log..." > "odl${i}_karaf.log"
    ssh "${!CONTROLLERIP}" head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log" >> "odl${i}_karaf.log"
    echo "dumping last 500K bytes of karaf log..." >> "odl${i}_karaf.log"
    ssh "${!CONTROLLERIP}" tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log" >> "odl${i}_karaf.log"
    echo "killing karaf process..."
    ssh "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done
sleep 5
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    ssh "${!CONTROLLERIP}" xz -9ekvv "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.xz" "odl${i}_karaf.log.xz"
done

scp ${OPENSTACK_CONTROL_NODE_IP}:/opt/stack/devstack/nohup.out "openstack_control_stack.log"
for i in `seq 1 $((NUM_OPENSTACK_SYSTEM - 1))
do
    OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    scp "${!OSIP}:/opt/stack/devstack/nohup.out" "openstack_compute_stack_${i}.log"
done

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
