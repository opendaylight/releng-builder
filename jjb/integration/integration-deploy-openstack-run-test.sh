#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate
PYTHON="${ROBOT_VENV}/bin/python"
SSH="ssh -t -t"
ADMIN_PASSWORD=admin

# TODO: remove this work to run changes.py if/when it's moved higher up to be visible at the Robot level
echo "showing recent changes that made it in to the distribution used by this job"
$PYTHON -m pip install --upgrade urllib3
python ${WORKSPACE}/test/tools/distchanges/changes.py -d /tmp/distribution_folder \
                  -u ${ACTUAL_BUNDLE_URL} -b ${DISTROBRANCH} \
                  -r ssh://jenkins-${SILO}@git.opendaylight.org:29418 || true

echo "#################################################"
echo "##         Deploy Openstack 3-node             ##"
echo "#################################################"

# Catch command errors and collect logs.
# This ensures logs are collected when script commands fail rather than simply exiting.
function trap_handler() {
    local prog="$0"
    local lastline="$1"
    local lasterr="$2"
    echo "${prog}: line ${lastline}: exit status of last command: ${lasterr}"
    echo "command: ${BASH_COMMAND}"
    collect_logs
    exit 1
} # trap_handler()

trap 'trap_handler ${LINENO} ${$?}' ERR

function create_etc_hosts() {
    NODE_IP=$1
    CTRL_IP=$2
    : > ${WORKSPACE}/hosts_file
    for iter in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`
    do
        COMPUTE_IP=OPENSTACK_COMPUTE_NODE_${iter}_IP
        if [ "${!COMPUTE_IP}" == "${NODE_IP}" ]; then
           CONTROL_HNAME=$(${SSH}  ${CTRL_IP}  "hostname")
           echo "${CTRL_IP}   ${CONTROL_HNAME}" >> ${WORKSPACE}/hosts_file
        else
           COMPUTE_HNAME=$(${SSH}  ${!COMPUTE_IP}  "hostname")
           echo "${!COMPUTE_IP}   ${COMPUTE_HNAME}" >> ${WORKSPACE}/hosts_file
        fi
    done

    echo "Created the hosts file for ${NODE_IP}:"
    cat ${WORKSPACE}/hosts_file
} # create_etc_hosts()

# convert commas in csv strings to spaces (ssv)
function csv2ssv() {
    local csv=$1
    if [ -n "${csv}" ]; then
        ssv=$(echo ${csv} | sed 's/,/ /g' | sed 's/\ \ */\ /g')
    fi

    echo "${ssv}"
} # csv2ssv

function create_control_node_local_conf() {
    HOSTIP=$1
    MGRIP=$2
    ODL_OVS_MANAGERS="$3"

    local_conf_file_name=${WORKSPACE}/local.conf_control_${HOSTIP}
    cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
USE_SCREEN=True
SCREEN_LOGDIR=/opt/stack/data/log
LOG_COLOR=False
RECLONE=${RECLONE}

disable_all_services
EOF

    CORE_OS_SERVICES="dstat,g-api,g-reg,key,mysql,n-api,n-cauth,n-cond,n-crt,n-obj,n-sch,odl-compute,odl-neutron,q-dhcp,q-meta,q-svc,rabbit"
    cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${CORE_OS_SERVICES}")
EOF
    if [ -n "${ENABLE_OS_SERVICES}" ]; then
        cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${ENABLE_OS_SERVICES}")
EOF
    fi
    if [ -n "${DISABLE_OS_SERVICES}" ]; then
        cat >> ${local_conf_file_name} << EOF
disable_service $(csv2ssv "${DISABLE_OS_SERVICES}")
EOF
    fi

    cat >> ${local_conf_file_name} << EOF

HOST_IP=${HOSTIP}
SERVICE_HOST=\$HOST_IP
Q_ML2_TENANT_NETWORK_TYPE=${TENANT_NETWORK_TYPE}
NEUTRON_CREATE_INITIAL_NETWORKS=${CREATE_INITIAL_NETWORKS}
#Q_PLUGIN=ml2
#ENABLE_TENANT_TUNNELS=True
#LIBVIRT_TYPE=qemu

ODL_MODE=manual
ODL_MGR_IP=${MGRIP}
ODL_PORT=8080
ODL_PORT_BINDING_CONTROLLER=${ODL_ML2_PORT_BINDING}
ODL_OVS_MANAGERS=${ODL_OVS_MANAGERS}

MYSQL_HOST=\$SERVICE_HOST
RABBIT_HOST=\$SERVICE_HOST
GLANCE_HOSTPORT=\$SERVICE_HOST:9292
KEYSTONE_AUTH_HOST=\$SERVICE_HOST
KEYSTONE_SERVICE_HOST=\$SERVICE_HOST

ADMIN_PASSWORD=${ADMIN_PASSWORD}
DATABASE_PASSWORD=${ADMIN_PASSWORD}
RABBIT_PASSWORD=${ADMIN_PASSWORD}
SERVICE_TOKEN=${ADMIN_PASSWORD}
SERVICE_PASSWORD=${ADMIN_PASSWORD}

NEUTRON_LBAAS_SERVICE_PROVIDERV2=${LBAAS_SERVICE_PROVIDER} # Only relevant if neutron-lbaas plugin is enabled
NEUTRON_SFC_DRIVERS=${ODL_SFC_DRIVER} # Only relevant if networking-sfc plugin is enabled
NEUTRON_FLOWCLASSIFIER_DRIVERS=${ODL_SFC_DRIVER} # Only relevant if networking-sfc plugin is enabled
ETCD_PORT=2379
EOF

    if [ "${ODL_ML2_DRIVER_VERSION}" == "v2" ]; then
        echo "ODL_V2DRIVER=True" >> ${local_conf_file_name}
    fi

    IFS=,
    for plugin_name in ${ENABLE_OS_PLUGINS}; do
        if [ "$plugin_name" == "networking-odl" ]; then
            ENABLE_PLUGIN_ARGS="${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}"
        elif [ "$plugin_name" == "kuryr-kubernetes" ]; then
            ENABLE_PLUGIN_ARGS="${DEVSTACK_KUBERNETES_PLUGIN_REPO} master" # note: kuryr-kubernetes only exists in master at the moment
        elif [ "$plugin_name" == "neutron-lbaas" ]; then
            ENABLE_PLUGIN_ARGS="${DEVSTACK_LBAAS_PLUGIN_REPO} ${OPENSTACK_BRANCH}"
            IS_LBAAS_PLUGIN_ENABLED="yes"
        elif [ "$plugin_name" == "networking-sfc" ]; then
            ENABLE_PLUGIN_ARGS="${DEVSTACK_NETWORKING_SFC_PLUGIN_REPO} ${OPENSTACK_BRANCH}"
        else
            echo "Error: Invalid plugin $plugin_name, unsupported"
            continue
        fi
        cat >> ${local_conf_file_name} << EOF

enable_plugin ${plugin_name} ${ENABLE_PLUGIN_ARGS}
EOF
    done
    unset IFS

    if [ "${ENABLE_NETWORKING_L2GW}" == "yes" ]; then
        cat >> ${local_conf_file_name} << EOF

enable_plugin networking-l2gw ${NETWORKING_L2GW_DRIVER} ${ODL_ML2_BRANCH}
NETWORKING_L2GW_SERVICE_DRIVER=L2GW:OpenDaylight:networking_odl.l2gateway.driver.OpenDaylightL2gwDriver:default
EOF
    fi

    if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
        cat >> ${local_conf_file_name} << EOF

PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ML2_VLAN_RANGES=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
EOF

        if [ "${ODL_ML2_DRIVER_VERSION}" == "v2" ]; then
           SERVICE_PLUGINS="odl-router_v2"
        else
           SERVICE_PLUGINS="odl-router"
        fi
        if [ "${ENABLE_NETWORKING_L2GW}" == "yes" ]; then
            SERVICE_PLUGINS+=", networking_l2gw.services.l2gateway.plugin.L2GatewayPlugin"
        fi
        if [ "${IS_LBAAS_PLUGIN_ENABLED}" == "yes" ]; then
            SERVICE_PLUGINS+=", lbaasv2"
        fi
    fi #check for ODL_ENABLE_L3_FWD

    cat >> ${local_conf_file_name} << EOF

[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
service_plugins = ${SERVICE_PLUGINS}

[[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
[agent]
minimize_polling=True

[ml2]
# Needed for VLAN provider tests - because our provider networks are always encapsulated in VXLAN (br-physnet1)
# MTU(1440) + VXLAN(50) + VLAN(4) = 1494 < MTU eth0/br-physnet1(1500)
physical_network_mtus = ${PUBLIC_PHYSICAL_NETWORK}:1440
path_mtu = 1490

# workaround for port-status not working due to https://bugs.opendaylight.org/show_bug.cgi?id=9092
[ml2_odl]
odl_features=nothing

[[post-config|/etc/neutron/dhcp_agent.ini]]
[DEFAULT]
force_metadata = True
enable_isolated_metadata = True

[[post-config|/etc/nova/nova.conf]]
[DEFAULT]
force_config_drive = False

[scheduler]
discover_hosts_in_cells_interval = 30
EOF

    echo "Control local.conf created:"
    cat ${local_conf_file_name}
} # create_control_node_local_conf()

function create_compute_node_local_conf() {
    HOSTIP=$1
    SERVICEHOST=$2
    MGRIP=$3
    ODL_OVS_MANAGERS="$4"

    local_conf_file_name=${WORKSPACE}/local.conf_compute_${HOSTIP}
    cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
LOG_COLOR=False
USE_SCREEN=True
SCREEN_LOGDIR=/opt/stack/data/log
RECLONE=${RECLONE}

disable_all_services
EOF

    CORE_OS_SERVICES="n-cpu,odl-compute"
    cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${CORE_OS_SERVICES}")
EOF
    if [ -n "${ENABLE_OS_COMPUTE_SERVICES}" ]; then
        cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${ENABLE_OS_COMPUTE_SERVICES}")
EOF
    fi
    if [ -n "${DISABLE_OS_SERVICES}" ]; then
        cat >> ${local_conf_file_name} << EOF
disable_service $(csv2ssv "${DISABLE_OS_SERVICES}")
EOF
    fi

    cat >> ${local_conf_file_name} << EOF

HOST_IP=${HOSTIP}
SERVICE_HOST=${SERVICEHOST}
Q_ML2_TENANT_NETWORK_TYPE=${TENANT_NETWORK_TYPE}
#Q_PLUGIN=ml2
#ENABLE_TENANT_TUNNELS=True
#LIBVIRT_TYPE=qemu
#MULTI_HOST=1

ODL_MODE=manual
ODL_MGR_IP=${MGRIP}
ODL_PORT=8080
ODL_PORT_BINDING_CONTROLLER=${ODL_ML2_PORT_BINDING}
ODL_OVS_MANAGERS=${ODL_OVS_MANAGERS}

Q_HOST=\$SERVICE_HOST
MYSQL_HOST=\$SERVICE_HOST
RABBIT_HOST=\$SERVICE_HOST
GLANCE_HOSTPORT=\$SERVICE_HOST:9292
KEYSTONE_AUTH_HOST=\$SERVICE_HOST
KEYSTONE_SERVICE_HOST=\$SERVICE_HOST

ADMIN_PASSWORD=${ADMIN_PASSWORD}
DATABASE_PASSWORD=${ADMIN_PASSWORD}
RABBIT_PASSWORD=${ADMIN_PASSWORD}
SERVICE_TOKEN=${ADMIN_PASSWORD}
SERVICE_PASSWORD=${ADMIN_PASSWORD}
EOF

    if [[ "${ENABLE_OS_PLUGINS}" =~ networking-odl ]]; then
        cat >> ${local_conf_file_name} << EOF

enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}
EOF
    fi

    if [ "${ODL_ENABLE_L3_FWD}" == "yes" ]; then
        cat >> ${local_conf_file_name} << EOF

PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
Q_L3_ENABLED=True
ODL_L3=${ODL_L3}
EOF
    fi

    cat >> ${local_conf_file_name} << EOF

[[post-config|/etc/nova/nova.conf]]
[api]
auth_strategy = keystone
[DEFAULT]
use_neutron = True
EOF

    echo "Compute local.conf created:"
    cat ${local_conf_file_name}
} # create_compute_node_local_conf()

function configure_haproxy_for_neutron_requests() {
    MGRIP=$1
    ODL_IPS=(${2//,/ })

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
    for odlip in ${ODL_IPS[*]}; do
        cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-${odlindex} ${odlip}:8080 check fall 5 inter 2000 rise 2
EOF
        odlindex=$((odlindex+1))
    done

    cat >> ${WORKSPACE}/haproxy.cfg << EOF
listen opendaylight_rest
  bind ${MGRIP}:8181
  balance source
EOF

    odlindex=1
    for odlip in ${ODL_IPS[*]}; do
        cat >> ${WORKSPACE}/haproxy.cfg << EOF
  server controller-rest-${odlindex} ${odlip}:8181 check fall 5 inter 2000 rise 2
EOF
        odlindex=$((odlindex+1))
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
} # configure_haproxy_for_neutron_requests()

function collect_logs () {
    set +e  # We do not want to create red dot just because something went wrong while fetching logs.
    for i in `seq 1 ${NUM_ODL_SYSTEM}`; do
        CONTROLLERIP=ODL_SYSTEM_${i}_IP
        echo "Lets's take the karaf thread dump again..."
        KARAF_PID=$(ssh ${!CONTROLLERIP} "ps aux | grep ${KARAF_ARTIFACT} | grep -v grep | tr -s ' ' | cut -f2 -d' '")
        ssh ${!CONTROLLERIP} "jstack $KARAF_PID"> ${WORKSPACE}/karaf_${i}_threads_after.log || true
        echo "killing karaf process..."
        ${SSH} "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
    done

    cat > extra_debug.sh << EOF
echo -e "/usr/sbin/lsmod | /usr/bin/grep openvswitch\n"
/usr/sbin/lsmod | /usr/bin/grep openvswitch
echo -e "\ngrep ct_ /var/log/openvswitch/ovs-vswitchd.log\n"
grep ct_ /var/log/openvswitch/ovs-vswitchd.log
echo -e "\novsdb-tool -mm show-log\n"
ovsdb-tool -mm show-log
echo -e "\nsudo netstat -punta\n"
sudo netstat -punta
echo -e "\nsudo getenforce\n"
sudo getenforce
echo -e "\njournalctl > /tmp/journalctl.log\n"
journalctl > /tmp/journalctl.log
EOF

    sleep 5
    # FIXME: Do not create .tar and gzip before copying.
    for i in `seq 1 ${NUM_ODL_SYSTEM}`; do
        CONTROLLERIP=ODL_SYSTEM_${i}_IP
        ${SSH} "${!CONTROLLERIP}"  "cp -r /tmp/${BUNDLEFOLDER}/data/log /tmp/odl_log"
        ${SSH} "${!CONTROLLERIP}"  "tar -cf /tmp/odl${i}_karaf.log.tar /tmp/odl_log/*"
        scp "${!CONTROLLERIP}:/tmp/odl${i}_karaf.log.tar" "${WORKSPACE}/odl${i}_karaf.log.tar"
        ${SSH} "${!CONTROLLERIP}"  "tar -cf /tmp/odl${i}_zrpcd.log.tar /tmp/zrpcd.init.log"
        scp "${!CONTROLLERIP}:/tmp/odl${i}_zrpcd.log.tar" "${WORKSPACE}/odl${i}_zrpcd.log.tar"
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
    for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
        OS_CTRL_IP=OPENSTACK_CONTROL_NODE_${i}_IP
        OS_CTRL_FOLDER="control_${i}"
        mkdir -p ${OS_CTRL_FOLDER}
        scp ${!OS_CTRL_IP}:/opt/stack/devstack/nohup.out ${OS_CTRL_FOLDER}/stack.log
        scp ${!OS_CTRL_IP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_CTRL_FOLDER}/ovs-vswitchd.log
        scp ${!OS_CTRL_IP}:/etc/neutron/plugins/ml2/ml2_conf.ini ${OS_CTRL_FOLDER}
        scp ${!OS_CTRL_IP}:/etc/neutron/dhcp_agent.ini ${OS_CTRL_FOLDER}
        scp ${!OS_CTRL_IP}:/etc/neutron/neutron.conf ${OS_CTRL_FOLDER}/neutron.conf
        scp ${!OS_CTRL_IP}:/etc/nova/nova.conf ${OS_CTRL_FOLDER}/nova.conf
        scp ${!OS_CTRL_IP}:/etc/kuryr/kuryr.conf ${OS_CTRL_FOLDER}/kuryr.conf
        scp ${!OS_CTRL_IP}:/etc/neutron/neutron_lbaas.conf ${OS_CTRL_FOLDER}/neutron-lbaas.conf
        scp ${!OS_CTRL_IP}:/etc/neutron/services/loadbalancer/haproxy/lbaas_agent.ini ${OS_CTRL_FOLDER}/lbaas-agent.ini
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OS_CTRL_IP}:/usr/lib/systemd/system/haproxy.service ${OS_CTRL_FOLDER}
        rsync -avhe ssh ${!OS_CTRL_IP}:/opt/stack/logs/* ${OS_CTRL_FOLDER} # rsync to prevent copying of symbolic links
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OS_CTRL_IP}:/etc/hosts ${OS_CTRL_FOLDER}/hosts.log
        # Use rsync with sudo to get access to the log dir.
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OS_CTRL_IP}:/var/log/audit/audit.log ${OS_CTRL_FOLDER}
        scp ${!OS_CTRL_IP}:/tmp/get_devstack.sh.txt ${OS_CTRL_FOLDER}
        scp extra_debug.sh ${!OS_CTRL_IP}:/tmp
        ${SSH} ${!OS_CTRL_IP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
        scp ${!OS_CTRL_IP}:/tmp/extra_debug.log ${OS_CTRL_FOLDER}/extra_debug.log
        scp ${!OS_CTRL_IP}:/tmp/journalctl.log ${OS_CTRL_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OS_CTRL_IP}:/var/log/messages ${OS_CTRL_FOLDER}
        scp ${!OS_CTRL_IP}:/tmp/*.xz ${OS_CTRL_FOLDER}/
        mv local.conf_control_${!OS_CTRL_IP} ${OS_CTRL_FOLDER}/local.conf
        mv ${OS_CTRL_FOLDER} ${WORKSPACE}/archives/
    done

    # Compute Nodes
    for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
        OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
        OS_COMPUTE_FOLDER="compute_${i}"
        mkdir -p ${OS_COMPUTE_FOLDER}
        scp ${!OSIP}:/opt/stack/devstack/nohup.out ${OS_COMPUTE_FOLDER}/stack.log
        scp ${!OSIP}:/var/log/openvswitch/ovs-vswitchd.log ${OS_COMPUTE_FOLDER}/ovs-vswitchd.log
        scp ${!OSIP}:/var/log/openvswitch/ovsdb-server.log ${OS_COMPUTE_FOLDER}/ovsdb-server.log
        scp ${!OSIP}:/var/log/libvirt/libvirtd.log* ${OS_COMPUTE_FOLDER}
        scp ${!OSIP}:/var/log/libvirt/qeum/*.log ${OS_COMPUTE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova.conf ${OS_COMPUTE_FOLDER}/nova.conf
        rsync -avhe ssh ${!OSIP}:/opt/stack/logs/* ${OS_COMPUTE_FOLDER} # rsync to prevent copying of symbolic links
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/etc/hosts ${OS_COMPUTE_FOLDER}/hosts.log
        # Use rsync with sudo to get access to the log dir. Also can't use wildcard because the dirs only have
        # exec permissions which doesn't allow ls.
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/libvirt ${OS_COMPUTE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/audit/audit.log ${OS_COMPUTE_FOLDER}
        scp ${!OSIP}:/tmp/get_devstack.sh.txt ${OS_COMPUTE_FOLDER}
        scp extra_debug.sh ${!OSIP}:/tmp
        ${SSH} ${!OSIP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log"
        scp ${!OSIP}:/tmp/extra_debug.log ${OS_COMPUTE_FOLDER}/extra_debug.log
        scp ${!OSIP}:/tmp/journalctl.log ${OS_COMPUTE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/messages ${OS_COMPUTE_FOLDER}
        scp ${!OSIP}:/tmp/*.xz ${OS_COMPUTE_FOLDER}/
        mv local.conf_compute_${!OSIP} ${OS_COMPUTE_FOLDER}/local.conf
        mv ${OS_COMPUTE_FOLDER} ${WORKSPACE}/archives/
    done

    # Find all the local.conf files and append .log so they are archived
    find local.conf* -print0 | xargs -0 -I % mv % %.log

    # Tempest
    DEVSTACK_TEMPEST_DIR="/opt/stack/tempest"
    if ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo sh -c '[ -f ${DEVSTACK_TEMPEST_DIR}/.testrepository/0 ]'"; then # if Tempest results exist
        ssh ${OPENSTACK_CONTROL_NODE_1_IP} "for I in \$(sudo ls ${DEVSTACK_TEMPEST_DIR}/.testrepository/ | grep -E '^[0-9]+$'); do sudo sh -c \"${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/subunit-1to2 < ${DEVSTACK_TEMPEST_DIR}/.testrepository/\${I} >> ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt\"; done"
        ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo sh -c '${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/python ${DEVSTACK_TEMPEST_DIR}/.tox/tempest/lib/python2.7/site-packages/os_testr/subunit2html.py ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt ${DEVSTACK_TEMPEST_DIR}/tempest_results.html'"
        TEMPEST_LOGS_DIR=${WORKSPACE}/archives/tempest
        mkdir -p ${TEMPEST_LOGS_DIR}
        scp ${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest_results.html ${TEMPEST_LOGS_DIR}
        scp ${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest.log ${TEMPEST_LOGS_DIR}
        mv ${WORKSPACE}/tempest_output* ${TEMPEST_LOGS_DIR}
    fi
} # collect_logs()

if [ "${ODL_ML2_BRANCH}" != "stable/ocata" ]; then
   RECLONE=no
else
   RECLONE=yes
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

# if we are using the old netvirt impl, as determined by the feature name
# odl-ovsdb-openstack (note: new impl is odl-netvirt-openstack) then we
# want ODL_L3 to be True.  New impl wants it False
if [[ ${CONTROLLERFEATURES} == *"odl-ovsdb-openstack"* ]]; then
    ODL_L3=True
else
    ODL_L3=False
fi

cat > ${WORKSPACE}/disable_firewall.sh << EOF
sudo systemctl stop firewalld
sudo systemctl stop iptables
true
EOF

cat > ${WORKSPACE}/get_devstack.sh << EOF
sudo systemctl stop firewalld
sudo yum install bridge-utils python-pip -y
#sudo systemctl stop  NetworkManager
#Disable NetworkManager and kill dhclient and dnsmasq
sudo systemctl stop NetworkManager
sudo killall dhclient
sudo killall dnsmasq
#Workaround for mysql failure
echo "127.0.0.1   localhost \${HOSTNAME}" >> /tmp/hosts
echo "::1         localhost \${HOSTNAME}" >> /tmp/hosts
sudo mv /tmp/hosts /etc/hosts
sudo mkdir /opt/stack
sudo chmod 777 /opt/stack
cd /opt/stack
echo "git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}"
git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}
cd devstack
if [ -n "${DEVSTACK_HASH}" ]; then
    echo "git checkout ${DEVSTACK_HASH}"
    git checkout ${DEVSTACK_HASH}
fi
git --no-pager log --pretty=format:'%h %<(13)%ar%<(13)%cr %<(20,trunc)%an%d %s\n%b' -n20
EOF

cat > "${WORKSPACE}/setup_host_cell_mapping.sh" << EOF
sudo nova-manage cell_v2 map_cell0
sudo nova-manage cell_v2 simple_cell_setup
sudo nova-manage db sync
sudo nova-manage cell_v2 discover_hosts
EOF

NUM_OPENSTACK_SITES=${NUM_OPENSTACK_SITES:-1}
compute_index=1
odl_index=1
os_node_list=()
os_interval=$(( ${NUM_OPENSTACK_SYSTEM} / ${NUM_OPENSTACK_SITES} ))
ha_proxy_index=${os_interval}

for i in `seq 1 ${NUM_OPENSTACK_SITES}`; do
    if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
        echo "Configure HAProxy"
        ODL_HAPROXYIP_PARAM=OPENSTACK_HAPROXY_${i}_IP
        ha_proxy_index=$(( $ha_proxy_index + $os_interval ))
        odl_index=$(((i - 1) * 3 + 1))
        ODL_IP_PARAM1=ODL_SYSTEM_$((odl_index++))_IP
        ODL_IP_PARAM2=ODL_SYSTEM_$((odl_index++))_IP
        ODL_IP_PARAM3=ODL_SYSTEM_$((odl_index++))_IP
        ODLMGRIP[$i]=${!ODL_HAPROXYIP_PARAM} # ODL Northbound uses HAProxy VIP
        ODL_OVS_MGRS[$i]="${!ODL_IP_PARAM1},${!ODL_IP_PARAM2},${!ODL_IP_PARAM3}" # OVSDB connects to all ODL IPs
        configure_haproxy_for_neutron_requests ${!ODL_HAPROXYIP_PARAM} "${ODL_OVS_MGRS[$i]}"
    else
        ODL_IP_PARAM=ODL_SYSTEM_${i}_IP
        ODL_OVS_MGRS[$i]="${!ODL_IP_PARAM}" # ODL Northbound uses ODL IP
        ODLMGRIP[$i]=${!ODL_IP_PARAM} # OVSDB connects to ODL IP
    fi
done

# Begin stacking the nodes, starting with the controller(s) and then the compute(s)

for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
    CONTROLIP=OPENSTACK_CONTROL_NODE_${i}_IP
    echo "Stack the control node ${i} of ${NUM_OPENSTACK_CONTROL_NODES}: ${CONTROLIP}"
    create_etc_hosts ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!CONTROLIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh ${!CONTROLIP}:/tmp
    ${SSH} ${!CONTROLIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    create_control_node_local_conf ${!CONTROLIP} ${ODLMGRIP[$i]} "${ODL_OVS_MGRS[$i]}"
    scp ${WORKSPACE}/local.conf_control_${!CONTROLIP} ${!CONTROLIP}:/opt/stack/devstack/local.conf
    ssh ${!CONTROLIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
    ssh ${!CONTROLIP} "ps -ef | grep stack.sh"
    ssh ${!CONTROLIP} "ls -lrt /opt/stack/devstack/nohup.out"
    os_node_list+=(${!CONTROLIP})
    # Workaround for stable/newton jobs
    # TODO: can this be removed now?
    if [ "${ODL_ML2_BRANCH}" == "stable/newton" ]; then
        ssh ${!CONTROLIP} "cd /opt/stack; git clone https://git.openstack.org/openstack/requirements; cd requirements; git checkout stable/newton; sed -i /appdirs/d upper-constraints.txt"
    fi
done

for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
    NUM_COMPUTES_PER_SITE=$((NUM_OPENSTACK_COMPUTE_NODES / NUM_OPENSTACK_SITES))
    SITE_INDEX=$((((i - 1) / NUM_COMPUTES_PER_SITE) + 1)) # We need the site index to infer the control node IP for this compute
    COMPUTEIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    CONTROLIP=OPENSTACK_CONTROL_NODE_${SITE_INDEX}_IP
    echo "Stack the compute node ${i} of ${NUM_OPENSTACK_COMPUTE_NODES}: ${COMPUTEIP}"
    create_etc_hosts ${!COMPUTEIP} ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!COMPUTEIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
    ${SSH} ${!COMPUTEIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    create_compute_node_local_conf ${!COMPUTEIP} ${!CONTROLIP} ${ODLMGRIP[$SITE_INDEX]} "${ODL_OVS_MGRS[$SITE_INDEX]}"
    scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
    ssh ${!COMPUTEIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
    ssh ${!COMPUTEIP} "ps -ef | grep stack.sh"
    os_node_list+=(${!COMPUTEIP})
done

echo "nodelist: ${os_node_list[*]}"

# This script runs on the openstack nodes. It greps for a string that devstack writes when stacking is complete.
# The script then writes a status depending on the grep output that is later scraped by the robot vm to control
# the status polling.
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

# Check if the stacking is finished. Poll all nodes every 60s for one hour.
iteration=0
in_progress=1
while [ ${in_progress} -eq 1 ]; do
    iteration=$(($iteration + 1))
    for index in "${!os_node_list[@]}"; do
        echo "node $index ${os_node_list[index]}: checking stacking status attempt ${iteration} of 60"
        scp ${WORKSPACE}/check_stacking.sh  ${os_node_list[index]}:/tmp
        ${SSH} ${os_node_list[index]} "bash /tmp/check_stacking.sh"
        scp ${os_node_list[index]}:/tmp/stack_progress .
        cat stack_progress
        stacking_status=`cat stack_progress`
        if [ "$stacking_status" == "Still Stacking" ]; then
            continue
        elif [ "$stacking_status" == "Stacking Failed" ]; then
            echo "node $index ${os_node_list[index]}: stacking has failed"
            collect_logs
            exit 1
        elif [ "$stacking_status" == "Stacking Complete" ]; then
            echo "node $index ${os_node_list[index]}: stacking complete"
            unset 'os_node_list[index]'
            if  [ ${#os_node_list[@]} -eq 0 ]; then
                in_progress=0
            fi
        fi
    done
    echo "sleep for a minute before the next check"
    sleep 60
    if [ ${iteration} -eq 60 ]; then
        echo "stacking has failed - took longer than 60m"
        collect_logs
        exit 1
    fi
done

# Further configuration now that stacking is complete.
NUM_COMPUTES_PER_SITE=$((NUM_OPENSTACK_COMPUTE_NODES / NUM_OPENSTACK_SITES))
for i in `seq 1 ${NUM_OPENSTACK_SITES}`; do
    echo "Configure the Control Node"
    CONTROLIP=OPENSTACK_CONTROL_NODE_${i}_IP
    # Gather Compute IPs for the site
    for j in `seq 1 ${NUM_COMPUTES_PER_SITE}`; do
        COMPUTE_INDEX=$(((i-1) * NUM_COMPUTES_PER_SITE + j))
        IP_VAR=OPENSTACK_COMPUTE_NODE_${COMPUTE_INDEX}_IP
        COMPUTE_IPS[$((j-1))]=${!IP_VAR}
    done

    # Need to disable firewalld and iptables in compute nodes as well
    for ip in ${COMPUTE_IPS[*]}; do
        scp ${WORKSPACE}/disable_firewall.sh "${ip}:/tmp"
        ${SSH} "${ip}" "sudo bash /tmp/disable_firewall.sh"
    done

    #Need to disable firewalld and iptables in control node
    echo "Stop Firewall in Control Node for compute nodes to be able to reach the ports and add to hypervisor-list"
    scp ${WORKSPACE}/disable_firewall.sh ${!CONTROLIP}:/tmp
    ${SSH} ${!CONTROLIP} "sudo bash /tmp/disable_firewall.sh"

    echo "sleep for 60s and print hypervisor-list"
    sleep 60
    # In anything after Newton, if we do not enable the n-cpu in control node
    # We need to discover hosts manually and ensure that they are mapped to cells.
    # reference: https://ask.openstack.org/en/question/102256/how-to-configure-placement-service-for-compute-node-on-ocata/
    if [ "${OPENSTACK_BRANCH}" == "stable/ocata" ]; then
        scp ${WORKSPACE}/setup_host_cell_mapping.sh  ${!CONTROLIP}:/tmp
        ${SSH} ${!CONTROLIP} "sudo bash /tmp/setup_host_cell_mapping.sh"
    fi
    ${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; nova hypervisor-list"
    # in the case that we are doing openstack (control + compute) all in one node, then the number of hypervisors
    # will be the same as the number of openstack systems. However, if we are doing multinode openstack then the
    # assumption is we have a single control node and the rest are compute nodes, so the number of expected hypervisors
    # is one less than the total number of openstack systems
    if [ $((NUM_OPENSTACK_SYSTEM / NUM_OPENSTACK_SITES)) -eq 1 ]; then
        expected_num_hypervisors=1
    else
        expected_num_hypervisors=${NUM_COMPUTES_PER_SITE}
    fi
    num_hypervisors=$(${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; openstack hypervisor list -f value | wc -l" | tail -1 | tr -d "\r")
    if ! [ "${num_hypervisors}" ] || ! [ ${num_hypervisors} -eq ${expected_num_hypervisors} ]; then
        echo "Error: Only $num_hypervisors hypervisors detected, expected $expected_num_hypervisors"
        collect_logs
        exit 1
    fi

    # upgrading pip, urllib3 and httplib2 so that tempest tests can be run on openstack control node
    # this needs to happen after devstack runs because it seems devstack is pulling in specific versions
    # of these libs that are not working for tempest.
    ${SSH} ${!CONTROLIP} "sudo pip install --upgrade pip"
    ${SSH} ${!CONTROLIP} "sudo pip install urllib3 --upgrade"
    ${SSH} ${!CONTROLIP} "sudo pip install httplib2 --upgrade"

    # Gather Compute IPs for the site
    for j in `seq 1 ${NUM_COMPUTES_PER_SITE}`; do
        COMPUTE_INDEX=$(((i-1) * NUM_COMPUTES_PER_SITE + j))
        IP_VAR=OPENSTACK_COMPUTE_NODE_${COMPUTE_INDEX}_IP
        COMPUTE_IPS[$((j-1))]=${!IP_VAR}
    done

    # Need to disable firewalld and iptables in compute nodes as well
    for ip in ${COMPUTE_IPS[*]}; do
        scp ${WORKSPACE}/disable_firewall.sh "${ip}:/tmp"
        ${SSH} "${ip}" "sudo bash /tmp/disable_firewall.sh"
    done

    # External Network
    echo "prepare external networks by adding vxlan tunnels between all nodes on a separate bridge..."
    # FIXME Should there be a unique gateway IP and devstack index for each site?
    devstack_index=1
    for ip in ${!CONTROLIP} ${COMPUTE_IPS[*]}; do
        # FIXME - Workaround, ODL (new netvirt) currently adds PUBLIC_BRIDGE as a port in br-int since it doesn't see such a bridge existing when we stack
        ${SSH} $ip "sudo ovs-vsctl --if-exists del-port br-int $PUBLIC_BRIDGE"
        ${SSH} $ip "sudo ovs-vsctl --may-exist add-br $PUBLIC_BRIDGE -- set bridge $PUBLIC_BRIDGE other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:0$((devstack_index++))"
    done

    # ipsec support
    if [ "${IPSEC_VXLAN_TUNNELS_ENABLED}" == "yes" ]; then
        ALL_NODES=(${!CONTROLIP} ${COMPUTE_IPS[*]})
        for ((inx_ip1=0; inx_ip1<$((${#ALL_NODES[@]} - 1)); inx_ip1++)); do
            for ((inx_ip2=$((inx_ip1 + 1)); inx_ip2<${#ALL_NODES[@]}; inx_ip2++)); do
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

        for ip in ${!CONTROLIP} ${COMPUTE_IPS[*]}; do
            echo "ip xfrm configuration for node $ip:"
            ${SSH} $ip "sudo ip xfrm policy list"
            ${SSH} $ip "sudo ip xfrm state list"
        done
    fi

    # Control Node - PUBLIC_BRIDGE will act as the external router
    # Parameter values below are used in integration/test - changing them requires updates in intergration/test as well
    EXTNET_GATEWAY_IP="10.10.10.250"
    EXTNET_INTERNET_IP="10.9.9.9"
    EXTNET_PNF_IP="10.10.10.253"
    ${SSH} ${!CONTROLIP} "sudo ifconfig ${PUBLIC_BRIDGE} up ${EXTNET_GATEWAY_IP}/24"

    # Control Node - external net PNF simulation
    ${SSH} ${!CONTROLIP} "
        sudo ip netns add pnf_ns;
        sudo ip link add pnf_veth0 type veth peer name pnf_veth1;
        sudo ip link set pnf_veth1 netns pnf_ns;
        sudo ip link set pnf_veth0 up;
        sudo ip netns exec pnf_ns ifconfig pnf_veth1 up ${EXTNET_PNF_IP}/24;
        sudo ovs-vsctl add-port ${PUBLIC_BRIDGE} pnf_veth0;
    "

    # Control Node - external net internet address simulation
    ${SSH} ${!CONTROLIP} "
        sudo ip tuntap add dev internet_tap mode tap;
        sudo ifconfig internet_tap up ${EXTNET_INTERNET_IP}/24;
    "

    # Computes
    compute_index=1
    for compute_ip in ${COMPUTE_IPS[*]}; do
        # Tunnel from controller to compute
        COMPUTEPORT=compute$(( compute_index++ ))_vxlan
        ${SSH} ${!CONTROLIP} "
            sudo ovs-vsctl add-port $PUBLIC_BRIDGE $COMPUTEPORT -- set interface $COMPUTEPORT type=vxlan options:local_ip=${!CONTROLIP} options:remote_ip=$compute_ip options:dst_port=9876 options:key=flow
        "
        # Tunnel from compute to controller
        CONTROLPORT="control_vxlan"
        ${SSH} $compute_ip "
            sudo ovs-vsctl add-port $PUBLIC_BRIDGE $CONTROLPORT -- set interface $CONTROLPORT type=vxlan options:local_ip=$compute_ip options:remote_ip=${!CONTROLIP} options:dst_port=9876 options:key=flow
        "
    done
done

if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
    odlmgrip=OPENSTACK_HAPROXY_1_IP
    HA_PROXY_IP=${!odlmgrip}
    HA_PROXY_1_IP=${!odlmgrip}
    odlmgrip2=OPENSTACK_HAPROXY_2_IP
    HA_PROXY_2_IP=${!odlmgrip2}
    odlmgrip3=OPENSTACK_HAPROXY_1_IP
    HA_PROXY_3_IP=${!odlmgrip3}
else
    HA_PROXY_IP=${ODL_SYSTEM_IP}
    HA_PROXY_1_IP=${ODL_SYSTEM_1_IP}
    HA_PROXY_2_IP=${ODL_SYSTEM_2_IP}
    HA_PROXY_3_IP=${ODL_SYSTEM_3_IP}
fi

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
fi

if [ "${OPENSTACK_BRANCH}" == "stable/pike" ]; then
   AUTH="http://${!CONTROLIP}/identity"
else
   AUTH="http://${!CONTROLIP}:35357/v3"
fi

# Environment Variables Needed to execute Openstack Client for NetVirt Jobs
cat > /tmp/os_netvirt_client_rc << EOF
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL=${AUTH}
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_TENANT_NAME=admin
unset OS_CLOUD
EOF

source /tmp/os_netvirt_client_rc

echo "Starting Robot test suites ${SUITES} ..."
# please add pybot -v arguments on a single line and alphabetized
pybot -N ${TESTPLAN} --removekeywords wuks -c critical -e exclude -e skip_if_${DISTROSTREAM} \
    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
    -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} \
    -v CONTROLLER_USER:${USER} \
    -v DEVSTACK_DEPLOY_PATH:/opt/stack/devstack \
    -v HA_PROXY_IP:${HA_PROXY_IP} \
    -v HA_PROXY_1_IP:${HA_PROXY_1_IP} \
    -v HA_PROXY_2_IP:${HA_PROXY_2_IP} \
    -v HA_PROXY_3_IP:${HA_PROXY_3_IP} \
    -v JDKVERSION:${JDKVERSION} \
    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
    -v NUM_OPENSTACK_SITES:${NUM_OPENSTACK_SITES} \
    -v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} \
    -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
    -v ODL_SNAT_MODE:${ODL_SNAT_MODE} \
    -v ODL_STREAM:${DISTROSTREAM} \
    -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
    -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} \
    -v ODL_SYSTEM_2_IP:${ODL_SYSTEM_2_IP} \
    -v ODL_SYSTEM_3_IP:${ODL_SYSTEM_3_IP} \
    -v ODL_SYSTEM_4_IP:${ODL_SYSTEM_4_IP} \
    -v ODL_SYSTEM_5_IP:${ODL_SYSTEM_5_IP} \
    -v ODL_SYSTEM_6_IP:${ODL_SYSTEM_6_IP} \
    -v ODL_SYSTEM_7_IP:${ODL_SYSTEM_7_IP} \
    -v ODL_SYSTEM_8_IP:${ODL_SYSTEM_8_IP} \
    -v ODL_SYSTEM_9_IP:${ODL_SYSTEM_9_IP} \
    -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OS_CONTROL_NODE_1_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OS_CONTROL_NODE_2_IP:${OPENSTACK_CONTROL_NODE_2_IP} \
    -v OS_CONTROL_NODE_3_IP:${OPENSTACK_CONTROL_NODE_3_IP} \
    -v OPENSTACK_BRANCH:${OPENSTACK_BRANCH} \
    -v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} \
    -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
    -v OS_COMPUTE_3_IP:${OPENSTACK_COMPUTE_NODE_3_IP} \
    -v OS_COMPUTE_4_IP:${OPENSTACK_COMPUTE_NODE_4_IP} \
    -v OS_COMPUTE_5_IP:${OPENSTACK_COMPUTE_NODE_5_IP} \
    -v OS_COMPUTE_6_IP:${OPENSTACK_COMPUTE_NODE_6_IP} \
    -v OS_USER:${USER} \
    -v PUBLIC_PHYSICAL_NETWORK:${PUBLIC_PHYSICAL_NETWORK} \
    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
    -v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_1_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} \
    -v USER_HOME:${HOME} \
    -v WORKSPACE:/tmp \
    ${TESTOPTIONS} ${SUITES} || true

echo "Examining the files in data/log and checking file size"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
collect_logs

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
