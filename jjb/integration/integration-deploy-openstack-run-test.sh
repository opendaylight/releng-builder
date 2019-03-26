#!/bin/bash
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate
source /tmp/common-functions.sh ${BUNDLEFOLDER}
# Ensure we fail the job if any steps fail.
set -ex -o pipefail
totaltmr=$(timer)
get_os_deploy

PYTHON="${ROBOT_VENV}/bin/python"
SSH="ssh -t -t"
ADMIN_PASSWORD="admin"
OPENSTACK_MASTER_CLIENTS_VERSION="queens"
#Size of the partition to /opt/stack in control and compute nodes
TMPFS_SIZE=2G

# TODO: remove this work to run changes.py if/when it's moved higher up to be visible at the Robot level
printf "\nshowing recent changes that made it into the distribution used by this job:\n"
$PYTHON -m pip install --upgrade urllib3
python ${WORKSPACE}/test/tools/distchanges/changes.py -d /tmp/distribution_folder \
                  -u ${ACTUAL_BUNDLE_URL} -b ${DISTROBRANCH} \
                  -r ssh://jenkins-${SILO}@git.opendaylight.org:29418 || true

printf "\nshowing recent changes that made it into integration/test used by this job:\n"
cd ${WORKSPACE}/test
printf "Hash    Author Date                    Commit Date                    Author               Subject\n"
printf "%s\n" "------- ------------------------------ ------------------------------ -------------------- -----------------------------"
git --no-pager log --pretty=format:'%h %<(30)%ad %<(30)%cd %<(20,trunc)%an%d %s' -n20
printf "\n"
cd -

cat << EOF
#################################################
##         Deploy Openstack 3-node             ##
#################################################
EOF

# Catch command errors and collect logs.
# This ensures logs are collected when script commands fail rather than simply exiting.
function trap_handler() {
    local prog="$0"
    local lastline="$1"
    local lasterr="$2"
    echo "trap_handler: ${prog}: line ${lastline}: exit status of last command: ${lasterr}"
    echo "trap_handler: command: ${BASH_COMMAND}"
    exit 1
} # trap_handler()

trap 'trap_handler ${LINENO} ${$?}' ERR

print_job_parameters

function create_etc_hosts() {
    NODE_IP=$1
    CTRL_IP=$2
    : > ${WORKSPACE}/hosts_file
    for iter in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
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

#function to install Openstack Clients for Testing
#This will pull the latest versions compatiable with the
# openstack release
function install_openstack_clients_in_robot_vm() {
    packages=("python-novaclient" "python-neutronclient" "python-openstackclient")
    local os_plugins
    os_plugins=$(csv2ssv "${ENABLE_OS_PLUGINS}")
    for plugin_name in $os_plugins; do
        if [ "$plugin_name" == "networking-sfc" ]; then
            packages+=("networking-sfc")
        fi
    done
    openstack_version=$(echo ${OPENSTACK_BRANCH} | cut -d/ -f2)
    #If the job tests "master", we will use the clients from previous released stable version to avoid failures
    if [ "${openstack_version}" == "master" ]; then
       openstack_version=${OPENSTACK_MASTER_CLIENTS_VERSION}
    fi
    for package in ${packages[*]}; do
       echo "Get the current support version of the package ${package}"
       wget https://raw.githubusercontent.com/openstack/requirements/stable/${openstack_version}/upper-constraints.txt -O /tmp/constraints.txt 2>/dev/null
       echo "$PYTHON -m pip install --upgrade --no-deps ${package} --no-cache-dir -c /tmp/constraints.txt"
       $PYTHON -m pip install --upgrade --no-deps ${package} --no-cache-dir -c /tmp/constraints.txt
       echo "$PYTHON -m pip install ${package} --no-cache-dir -c /tmp/constraints.txt"
       $PYTHON -m pip install ${package} --no-cache-dir -c /tmp/constraints.txt
    done

    if [ "${ENABLE_NETWORKING_L2GW}" == "yes" ]; then
        #networking-l2gw is not officially available in any release yet. Getting the latest stable version.
        $PYTHON -m pip install networking-l2gw==11.0.0
    fi
}

#Function to install rdo release
# This will help avoiding installing wrong version of packages which causes
# functionality failures
function install_rdo_release() {
    local ip=$1
    case ${OPENSTACK_BRANCH} in
       *queens*)
          ${SSH} ${ip} "sudo yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-queens/rdo-release-queens-1.noarch.rpm"
          ;;

       master)
          ${SSH} ${ip} "sudo yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-queens/rdo-release-queens-1.noarch.rpm"
          ;;
    esac
}

# Involves just setting up the shared directory
function setup_live_migration_control() {
    local control_ip=$1
    printf "%s:Setup directory Share with NFS" "${control_ip}"
    cat > ${WORKSPACE}/setup_live_migration_control.sh << EOF
sudo mkdir --mode=777 /vm_instances
sudo chown -R jenkins:jenkins /vm_instances
sudo yum install -y nfs-utils
printf "/vm_instances *(rw,no_root_squash)" | sudo tee -a /etc/exports
sudo systemctl start rpcbind nfs-server
sudo exportfs
EOF
    scp ${WORKSPACE}/setup_live_migration_control.sh ${control_ip}:/tmp/setup_live_migration_control.sh
    ssh ${control_ip} "bash /tmp/setup_live_migration_control.sh"
}

#Fix Problem caused due to new libvirt version in CentOS repo.
#The libvirt-python 3.10 does not support all the new API exposed
#This fix will force devstack to use latest libvirt-python
#from pypi.org (latest version as of 06-Dec-2018)
function fix_libvirt_python_build() {
    local ip=$1

    if [ "${ODL_ML2_BRANCH}" == "stable/queens" ]; then
        ${SSH} ${ip} "
            cd /opt/stack;
            git clone https://git.openstack.org/openstack/requirements;
            cd requirements;
            git checkout stable/queens;
            sed -i s/libvirt-python===3.10.0/libvirt-python===4.10.0/ upper-constraints.txt
        "
   fi
}

# Involves mounting the share and configuring the libvirtd
function setup_live_migration_compute() {
    local compute_ip=$1
    local control_ip=$2
    printf "%s:Mount Shared directory from ${control_ip}" "${compute_ip}"
    printf "%s:Configure libvirt in listen mode" "${compute_ip}"
    cat >  ${WORKSPACE}/setup_live_migration_compute.sh << EOF
sudo yum install -y libvirt libvirt-devel nfs-utils
sudo crudini --verbose  --set --inplace /etc/libvirt/libvirtd.conf '' listen_tls 0
sudo crudini --verbose  --set --inplace /etc/libvirt/libvirtd.conf '' listen_tcp 1
sudo crudini --verbose  --set --inplace /etc/libvirt/libvirtd.conf '' auth_tcp '"none"'
sudo crudini --verbose  --set --inplace /etc/sysconfig/libvirtd '' LIBVIRTD_ARGS '"--listen"'
sudo mkdir --mode=777 -p /var/instances
sudo chown -R jenkins:jenkins /var/instances
sudo chmod o+x /var/instances
sudo systemctl start rpcbind
sudo mount -t nfs ${control_ip}:/vm_instances /var/instances
sudo mount
EOF
    scp ${WORKSPACE}/setup_live_migration_compute.sh ${compute_ip}:/tmp/setup_live_migration_compute.sh
    ssh ${compute_ip} "bash /tmp/setup_live_migration_compute.sh"
}

# Add enable_services and disable_services to the local.conf
function add_os_services() {
    local core_services=$1
    local enable_services=$2
    local disable_services=$3
    local local_conf_file_name=$4
    local enable_network_services=$5

    cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${core_services}")
EOF
    if [ -n "${enable_services}" ]; then
        cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${enable_services}")
EOF
    fi
    if [ -n "${disable_services}" ]; then
        cat >> ${local_conf_file_name} << EOF
disable_service $(csv2ssv "${disable_services}")
EOF
    fi
    if [ -n "${enable_network_services}" ]; then
        cat >> ${local_conf_file_name} << EOF
enable_service $(csv2ssv "${enable_network_services}")
EOF
    fi
}

function create_control_node_local_conf() {
    HOSTIP=$1
    MGRIP=$2
    ODL_OVS_MANAGERS="$3"

    local_conf_file_name=${WORKSPACE}/local.conf_control_${HOSTIP}
    cat > ${local_conf_file_name} << EOF
[[local|localrc]]
LOGFILE=stack.sh.log
LOG_COLOR=False
USE_SYSTEMD=True
RECLONE=${RECLONE}
# Increase the wait used by stack to poll for services
SERVICE_TIMEOUT=120

disable_all_services
EOF

    add_os_services "${CORE_OS_CONTROL_SERVICES}" "${ENABLE_OS_SERVICES}" "${DISABLE_OS_SERVICES}" "${local_conf_file_name}" "${ENABLE_OS_NETWORK_SERVICES}"

    cat >> ${local_conf_file_name} << EOF

HOST_IP=${HOSTIP}
SERVICE_HOST=\$HOST_IP
Q_ML2_TENANT_NETWORK_TYPE=${TENANT_NETWORK_TYPE}
NEUTRON_CREATE_INITIAL_NETWORKS=${CREATE_INITIAL_NETWORKS}

ODL_MODE=manual
ODL_MGR_IP=${MGRIP}
ODL_PORT=${ODL_PORT}
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
PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ML2_VLAN_RANGES=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
EOF
    if [ "${TENANT_NETWORK_TYPE}" == "local" ]; then
        cat >> ${local_conf_file_name} << EOF
ENABLE_TENANT_TUNNELS=false
EOF
    fi

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
            IS_SFC_PLUGIN_ENABLED="yes"
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
NETWORKING_L2GW_SERVICE_DRIVER=L2GW:OpenDaylight:networking_odl.l2gateway.driver_v2.OpenDaylightL2gwDriver:default
EOF
    fi

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
    if [ "${IS_SFC_PLUGIN_ENABLED}" == "yes" ]; then
        SERVICE_PLUGINS+=", networking_sfc.services.flowclassifier.plugin.FlowClassifierPlugin,networking_sfc.services.sfc.plugin.SfcPlugin"
    fi

    cat >> ${local_conf_file_name} << EOF

[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
service_plugins = ${SERVICE_PLUGINS}
log_dir = /opt/stack/logs

[[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
[agent]
minimize_polling=True

[ml2]
# Needed for VLAN provider tests - because our provider networks are always encapsulated in VXLAN (br-physnet1)
# MTU(1400) + VXLAN(50) + VLAN(4) = 1454 < MTU eth0/br-physnet1(1458)
physical_network_mtus = ${PUBLIC_PHYSICAL_NETWORK}:1400
path_mtu = 1458
EOF
    if [ "${ENABLE_GRE_TYPE_DRIVERS}" == "yes" ]; then
        cat >> ${local_conf_file_name} << EOF
type_drivers = local,flat,vlan,gre,vxlan
[ml2_type_gre]
tunnel_id_ranges = 1:1000
EOF
    fi
    if [ "${ENABLE_NETWORKING_L2GW}" == "yes" ]; then
        cat >> ${local_conf_file_name} << EOF

[ml2_odl]
enable_dhcp_service = True
EOF
    fi

    cat >> ${local_conf_file_name} << EOF

[ml2_odl]
# Trigger n-odl full sync every 30 secs.
maintenance_interval = 30

[[post-config|/etc/neutron/dhcp_agent.ini]]
[DEFAULT]
force_metadata = True
enable_isolated_metadata = True
log_dir = /opt/stack/logs

[[post-config|/etc/nova/nova.conf]]
[scheduler]
discover_hosts_in_cells_interval = 30

[DEFAULT]
force_config_drive = False
force_raw_images = False
log_dir = /opt/stack/logs

EOF

    if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
        cat >> ${local_conf_file_name} << EOF
use_neutron = True
force_raw_images = False
log_dir = /opt/stack/logs
[libvirt]
live_migration_uri = qemu+tcp://%s/system
virt_type = qemu
EOF
    fi

    if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
        echo "Combo local.conf created:"
    else
        echo "Control local.conf created:"
    fi
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
USE_SYSTEMD=True
RECLONE=${RECLONE}
# Increase the wait used by stack to poll for the nova service on the control node
NOVA_READY_TIMEOUT=1800

disable_all_services
EOF

    add_os_services "${CORE_OS_COMPUTE_SERVICES}" "${ENABLE_OS_COMPUTE_SERVICES}" "${DISABLE_OS_SERVICES}" "${local_conf_file_name}"

    cat >> ${local_conf_file_name} << EOF
HOST_IP=${HOSTIP}
SERVICE_HOST=${SERVICEHOST}
Q_ML2_TENANT_NETWORK_TYPE=${TENANT_NETWORK_TYPE}

ODL_MODE=manual
ODL_MGR_IP=${MGRIP}
ODL_PORT=${ODL_PORT}
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

PUBLIC_BRIDGE=${PUBLIC_BRIDGE}
PUBLIC_PHYSICAL_NETWORK=${PUBLIC_PHYSICAL_NETWORK}
ODL_PROVIDER_MAPPINGS=${ODL_PROVIDER_MAPPINGS}
EOF

    if [[ "${ENABLE_OS_PLUGINS}" =~ networking-odl ]]; then
        cat >> ${local_conf_file_name} << EOF

enable_plugin networking-odl ${ODL_ML2_DRIVER_REPO} ${ODL_ML2_BRANCH}
EOF
    fi

    cat >> ${local_conf_file_name} << EOF

[[post-config|/etc/nova/nova.conf]]
[api]
auth_strategy = keystone
[DEFAULT]
use_neutron = True
force_raw_images = False
log_dir = /opt/stack/logs
[libvirt]
live_migration_uri = qemu+tcp://%s/system
virt_type = qemu
EOF

    echo "Compute local.conf created:"
    cat ${local_conf_file_name}
} # create_compute_node_local_conf()

function configure_haproxy_for_neutron_requests() {
    local -r haproxy_ip=$1
    # shellcheck disable=SC2206
    local -r odl_ips=(${2//,/ })

    cat > ${WORKSPACE}/install_ha_proxy.sh<< EOF
sudo systemctl stop firewalld
sudo yum -y install policycoreutils-python haproxy
EOF

    cat > ${WORKSPACE}/haproxy.cfg << EOF
global
  daemon
  group  haproxy
  log  /dev/log local0 debug
  maxconn  20480
  pidfile  /tmp/haproxy.pid
  ssl-default-bind-ciphers  !SSLv2:kEECDH:kRSA:kEDH:kPSK:+3DES:!aNULL:!eNULL:!MD5:!EXP:!RC4:!SEED:!IDEA:!DES
  ssl-default-bind-options  no-sslv3 no-tlsv10
  stats  socket /var/lib/haproxy/stats mode 600 level user
  stats  timeout 2m
  user  haproxy

defaults
  log  global
  option  log-health-checks
  maxconn  4096
  mode  tcp
  retries  3
  timeout  http-request 10s
  timeout  queue 2m
  timeout  connect 5s
  timeout  client 5s
  timeout  server 5s

listen opendaylight
  bind ${haproxy_ip}:8181 transparent
  mode http
  http-request set-header X-Forwarded-Proto https if { ssl_fc }
  http-request set-header X-Forwarded-Proto http if !{ ssl_fc }
  option httpchk GET /diagstatus
  option httplog
EOF

    odlindex=1
    for odlip in ${odl_ips[*]}; do
        echo "  server opendaylight-rest-${odlindex} ${odlip}:8181 check fall 5 inter 2000 rise 2" >> ${WORKSPACE}/haproxy.cfg
        odlindex=$((odlindex+1))
    done

    cat >> ${WORKSPACE}/haproxy.cfg << EOF

listen opendaylight_ws
  bind ${haproxy_ip}:8185 transparent
  mode http
  timeout tunnel 3600s
  option httpchk GET /data-change-event-subscription/neutron:neutron/neutron:ports/datastore=OPERATIONAL/scope=SUBTREE HTTP/1.1\r\nHost:\ ws.opendaylight.org\r\nConnection:\ Upgrade\r\nUpgrade:\ websocket\r\nSec-WebSocket-Key:\ haproxy\r\nSec-WebSocket-Version:\ 13\r\nSec-WebSocket-Protocol:\ echo-protocol
  http-check expect status 101
EOF

    odlindex=1
    for odlip in ${odl_ips[*]}; do
        echo "  server opendaylight-ws-${odlindex} ${odlip}:8185 check fall 3 inter 1000 rise 2" >> ${WORKSPACE}/haproxy.cfg
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

    scp ${WORKSPACE}/install_ha_proxy.sh ${haproxy_ip}:/tmp
    ${SSH} ${haproxy_ip} "sudo bash /tmp/install_ha_proxy.sh"
    scp ${WORKSPACE}/haproxy.cfg ${haproxy_ip}:/tmp
    scp ${WORKSPACE}/deploy_ha_proxy.sh ${haproxy_ip}:/tmp
    ${SSH} ${haproxy_ip} "sudo bash /tmp/deploy_ha_proxy.sh"
} # configure_haproxy_for_neutron_requests()

# Following three functions are debugging helpers when debugging devstack changes.
# Keeping them for now so we can simply call them when needed.
ctrlhn=""
comp1hn=""
comp2hn=""
function get_hostnames () {
    set +e
    local ctrlip=${OPENSTACK_CONTROL_NODE_1_IP}
    local comp1ip=${OPENSTACK_COMPUTE_NODE_1_IP}
    local comp2ip=${OPENSTACK_COMPUTE_NODE_2_IP}
    ctrlhn=$(${SSH} ${ctrlip} "hostname")
    comp1hn=$(${SSH} ${comp1ip} "hostname")
    comp2hn=$(${SSH} ${comp2ip} "hostname")
    echo "hostnames: ${ctrlhn}, ${comp1hn}, ${comp2hn}"
    set -e
}

function check_firewall() {
    set +e
    echo $-
    local ctrlip=${OPENSTACK_CONTROL_NODE_1_IP}
    local comp1ip=${OPENSTACK_COMPUTE_NODE_1_IP}
    local comp2ip=${OPENSTACK_COMPUTE_NODE_2_IP}

    echo "check_firewall on control"
    ${SSH} ${ctrlip} "
        sudo systemctl status firewalld
        sudo systemctl -l status iptables
        sudo iptables --line-numbers -nvL
    " || true
    echo "check_firewall on compute 1"
    ${SSH} ${comp1ip} "
        sudo systemctl status firewalld
        sudo systemctl -l status iptables
        sudo iptables --line-numbers -nvL
    " || true
    echo "check_firewall on compute 2"
    ${SSH} ${comp2ip} "
        sudo systemctl status firewalld
        sudo systemctl -l status iptables
        sudo iptables --line-numbers -nvL
    " || true
}

function get_service () {
    set +e
    local iter=$1
    #local idx=$2
    local ctrlip=${OPENSTACK_CONTROL_NODE_1_IP}
    local comp1ip=${OPENSTACK_COMPUTE_NODE_1_IP}

    #if [ ${idx} -eq 1 ]; then
        if [ ${iter} -eq 1 ] || [ ${iter} -gt 16 ]; then
            curl http://${ctrlip}:5000
            curl http://${ctrlip}:35357
            curl http://${ctrlip}/identity
            ${SSH} ${ctrlip} "
                source /opt/stack/devstack/openrc admin admin;
                env
                openstack configuration show --unmask;
                openstack service list
                openstack --os-cloud devstack-admin --os-region RegionOne compute service list
                openstack hypervisor list;
            " || true
            check_firewall
        fi
    #fi
    set -e
}

# Check if rabbitmq is ready by looking for a pid in it's status.
# The function returns the status of the grep command which callers can check.
function is_rabbitmq_ready() {
    local -r ip=${1}
    local grepfor="nova_cell1"
    rm -f rabbit.txt
    ${SSH} ${ip} "sudo rabbitmqctl list_vhosts" > rabbit.txt
    grep ${grepfor} rabbit.txt
}

# retry the given command ($3) until success for a number of iterations ($1)
# sleeping ($2) between tries.
function retry() {
    local -r -i max_tries=${1}
    local -r -i sleep_time=${2}
    local -r cmd=${3}
    local -i retries=1
    local -i rc=1
    while true; do
        echo "retry ${cmd}: attempt: ${retries}"
        ${cmd}
        rc=$?
        if ((${rc} == 0)); then
            break;
        else
            if ((${retries} == ${max_tries})); then
                break
            else
                ((retries++))
                sleep ${sleep_time}
            fi
        fi
    done
    return ${rc}
}

function install_ovs() {
    local -r node=${1}
    local -r rpm_path=${2}

    if [ "${OVS_INSTALL:0:1}" = "v" ]; then
       # An OVS version was given, so we build it ourselves from OVS git repo.
       # Only on the first node though, consecutive nodes will use RPMs
       # built for the first one.
       [ ! -d "${rpm_path}" ] && mkdir -p "${rpm_path}" && build_ovs ${node} ${OVS_INSTALL} "${rpm_path}"
       # Install OVS from path
       install_ovs_from_path ${node} "${rpm_path}"
    elif [ "${OVS_INSTALL:0:4}" = "http" ]; then
       # Otherwise, install from rpm repo directly.
       install_ovs_from_repo ${node} ${OVS_INSTALL}
    else
       echo "Expected either an OVS version git tag or a repo http url"
       exit 1
    fi
}

ODL_PROVIDER_MAPPINGS="\${PUBLIC_PHYSICAL_NETWORK}:${PUBLIC_BRIDGE}"
RECLONE=False
ODL_PORT=8181

# Always compare the lists below against the devstack upstream ENABLED_SERVICES in
# https://github.com/openstack-dev/devstack/blob/master/stackrc#L52
# ODL CSIT does not use vnc, cinder, q-agt, q-l3 or horizon so they are not included below.
# collect performance stats
CORE_OS_CONTROL_SERVICES="dstat"
# Glance
CORE_OS_CONTROL_SERVICES+=",g-api,g-reg"
# Keystone
CORE_OS_CONTROL_SERVICES+=",key"
# Nova - services to support libvirt
CORE_OS_CONTROL_SERVICES+=",n-api,n-api-meta,n-cauth,n-cond,n-crt,n-obj,n-sch"
# ODL - services to connect to ODL
CORE_OS_CONTROL_SERVICES+=",odl-compute,odl-neutron"
# Additional services
CORE_OS_CONTROL_SERVICES+=",mysql,rabbit"

# collect performance stats
CORE_OS_COMPUTE_SERVICES="dstat"
# computes only need nova and odl
CORE_OS_COMPUTE_SERVICES+=",n-cpu,odl-compute"

cat > ${WORKSPACE}/disable_firewall.sh << EOF
sudo systemctl stop firewalld
# Open these ports to match the tutorial vms
# http/https (80/443), samba (445), netbios (137,138,139)
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443,139,445 -j ACCEPT
sudo iptables -I INPUT -p udp -m multiport --dports 137,138 -j ACCEPT
# OpenStack services as well as vxlan tunnel ports 4789 and 9876
# identity public/admin (5000/35357), ampq (5672), vnc (6080), nova (8774), glance (9292), neutron (9696)
sudo sudo iptables -I INPUT -p tcp -m multiport --dports 5000,5672,6080,8774,9292,9696,35357 -j ACCEPT
sudo sudo iptables -I INPUT -p udp -m multiport --dports 4789,9876 -j ACCEPT
sudo iptables-save > /etc/sysconfig/iptables
sudo systemctl restart iptables
sudo iptables --line-numbers -nvL
true
EOF

#For SFC Tests a larger partition is required for creating instances with Ubuntu
if [[ "${ENABLE_OS_PLUGINS}" =~ networking-sfc ]]; then
   TMPFS_SIZE=12G
fi
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
echo "Create RAM disk for /opt/stack"
sudo mount -t tmpfs -o size=${TMPFS_SIZE} tmpfs /opt/stack
sudo chmod 777 /opt/stack
cd /opt/stack
echo "git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}"
git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}
cd devstack
if [ -n "${DEVSTACK_HASH}" ]; then
    echo "git checkout ${DEVSTACK_HASH}"
    git checkout ${DEVSTACK_HASH}
fi
wget https://raw.githubusercontent.com/shague/odl_tools/master/fix-logging.patch.txt -O /tmp/fix-logging.patch.txt
patch --verbose -p1 -i /tmp/fix-logging.patch.txt
git --no-pager log --pretty=format:'%h %<(13)%ar%<(13)%cr %<(20,trunc)%an%d %s%b' -n20
echo

echo "workaround: do not upgrade openvswitch"
sudo yum install -y yum-plugin-versionlock
sudo yum versionlock add openvswitch
EOF

cat > "${WORKSPACE}/setup_host_cell_mapping.sh" << EOF
sudo nova-manage cell_v2 map_cell0
sudo nova-manage cell_v2 simple_cell_setup
sudo nova-manage db sync
sudo nova-manage cell_v2 discover_hosts
EOF

cat > "${WORKSPACE}/workaround_networking_sfc.sh" << EOF
cd /opt/stack
git clone https://git.openstack.org/openstack/networking-sfc
cd networking-sfc
git checkout ${OPENSTACK_BRANCH}
git checkout master -- devstack/plugin.sh
EOF

NUM_OPENSTACK_SITES=${NUM_OPENSTACK_SITES:-1}
compute_index=1
os_node_list=()

if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
    echo "Configure HAProxy"
    ODL_HAPROXYIP_PARAM=OPENSTACK_HAPROXY_1_IP
    ODL_IP_PARAM1=ODL_SYSTEM_1_IP
    ODL_IP_PARAM2=ODL_SYSTEM_2_IP
    ODL_IP_PARAM3=ODL_SYSTEM_3_IP
    ODLMGRIP=${!ODL_HAPROXYIP_PARAM} # ODL Northbound uses HAProxy VIP
    ODL_OVS_MGRS="${!ODL_IP_PARAM1},${!ODL_IP_PARAM2},${!ODL_IP_PARAM3}" # OVSDB connects to all ODL IPs
    configure_haproxy_for_neutron_requests ${!ODL_HAPROXYIP_PARAM} "${ODL_OVS_MGRS}"
else
    ODL_IP_PARAM=ODL_SYSTEM_1_IP
    ODLMGRIP=${!ODL_IP_PARAM} # OVSDB connects to ODL IP
    ODL_OVS_MGRS="${!ODL_IP_PARAM}" # ODL Northbound uses ODL IP
fi

os_ip_list=()
for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
    cip=OPENSTACK_CONTROL_NODE_${i}_IP
    ip=${!cip}
    os_ip_list+=("${ip}")
done

for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
    cip=OPENSTACK_COMPUTE_NODE_${i}_IP
    ip=${!cip}
    os_ip_list+=("${ip}")
done

for i in "${!os_ip_list[@]}"; do
    ip=${os_ip_list[i]}
    tcpdump_start "${i}" "${ip}" "port 6653"
done


# Begin stacking the nodes, starting with the controller(s) and then the compute(s)

for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
    CONTROLIP=OPENSTACK_CONTROL_NODE_${i}_IP
    echo "Configure the stack of the control node ${i} of ${NUM_OPENSTACK_CONTROL_NODES}: ${!CONTROLIP}"
    scp ${WORKSPACE}/disable_firewall.sh ${!CONTROLIP}:/tmp
    ${SSH} ${!CONTROLIP} "sudo bash /tmp/disable_firewall.sh"
    create_etc_hosts ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!CONTROLIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh ${!CONTROLIP}:/tmp
    # devstack Master is yet to migrate fully to lib/neutron, there are some ugly hacks that is
    # affecting the stacking.
    # Workaround For Queens, Make the physical Network as physnet1 in lib/neutron
    # In Queens the neutron new libs are used and do not have the following options from Pike and earlier:
    # Q_ML2_PLUGIN_FLAT_TYPE_OPTIONS could be used for the flat_networks
    # and Q_ML2_PLUGIN_VLAN_TYPE_OPTIONS could be used for the ml2_type_vlan
    ${SSH} ${!CONTROLIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    if [ "${ODL_ML2_BRANCH}" == "stable/queens" ]; then
       ssh ${!CONTROLIP} "sed -i 's/flat_networks public/flat_networks public,physnet1/' /opt/stack/devstack/lib/neutron"
       ssh ${!CONTROLIP} "sed -i '186i iniset \$NEUTRON_CORE_PLUGIN_CONF ml2_type_vlan network_vlan_ranges public:1:4094,physnet1:1:4094' /opt/stack/devstack/lib/neutron"
       #Workaround for networking-sfc to configure the paramaters in neutron.conf if the
       # services used are neutron-api, neutron-dhcp etc instead of q-agt.
       # Can be removed if the patch https://review.openstack.org/#/c/596287/ gets merged
       if [[ "${ENABLE_OS_PLUGINS}" =~ networking-sfc ]]; then
           scp ${WORKSPACE}/workaround_networking_sfc.sh ${!CONTROLIP}:/tmp/
           ssh ${!CONTROLIP} "bash -x /tmp/workaround_networking_sfc.sh"
       fi
    fi
    create_control_node_local_conf ${!CONTROLIP} ${ODLMGRIP} "${ODL_OVS_MGRS}"
    scp ${WORKSPACE}/local.conf_control_${!CONTROLIP} ${!CONTROLIP}:/opt/stack/devstack/local.conf
    echo "Install rdo release to avoid incompatible Package versions"
    install_rdo_release ${!CONTROLIP}
    setup_live_migration_control ${!CONTROLIP}
    if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
        setup_live_migration_compute ${!CONTROLIP} ${!CONTROLIP}
    fi
    [ -n "${OVS_INSTALL}" ] && install_ovs ${!CONTROLIP} /tmp/ovs_rpms
    if [[ "${ENABLE_OS_PLUGINS}" =~ networking-sfc ]]; then
        # This should be really done by networking-odl devstack plugin,
        # but in the meantime do it ourselves
        ssh ${!CONTROLIP} "sudo ovs-vsctl set Open_vSwitch . external_ids:of-tunnel=true"
    fi
    fix_libvirt_python_build ${!CONTROLIP}
    echo "Stack the control node ${i} of ${NUM_OPENSTACK_CONTROL_NODES}: ${CONTROLIP}"
    # Workaround: fixing boneheaded polkit issue, to be removed later
    ssh ${!CONTROLIP} "sudo bash -c 'echo deltarpm=0 >> /etc/yum.conf && yum -y update polkit'"
    ssh ${!CONTROLIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
    ssh ${!CONTROLIP} "ps -ef | grep stack.sh"
    ssh ${!CONTROLIP} "ls -lrt /opt/stack/devstack/nohup.out"
    os_node_list+=("${!CONTROLIP}")
done

# This is a backup to the CELLSV2_SETUP=singleconductor workaround. Keeping it here as an easy lookup
# if needed.
# Let the control node get started to avoid a race condition where the computes start and try to access
# the nova_cell1 on the control node before it is created. If that happens, the nova-compute service on the
# compute exits and does not attempt to restart.
# 180s is chosen because in test runs the control node usually finished in 17-20 minutes and the computes finished
# in 17 minutes, so take the max difference of 3 minutes and the jobs should still finish around the same time.
# one of the following errors is seen in the compute n-cpu.log:
# Unhandled error: NotAllowed: Connection.open: (530) NOT_ALLOWED - access to vhost 'nova_cell1' refused for user 'stackrabbit'
# AccessRefused: (0, 0): (403) ACCESS_REFUSED - Login was refused using authentication mechanism AMQPLAIN. For details see the broker logfile.
# Compare that timestamp to this log in the control stack.log: sudo rabbitmqctl set_permissions -p nova_cell1 stackrabbit
# If the n-cpu.log is earlier than the control stack.log timestamp then the failure condition is likely hit.
if [ ${NUM_OPENSTACK_COMPUTE_NODES} -gt 0 ]; then
    WAIT_FOR_RABBITMQ_MINUTES=60
    echo "Wait a maximum of ${WAIT_FOR_RABBITMQ_MINUTES}m until rabbitmq is ready and nova_cell1 created to allow the controller to create nova_cell1 before the computes need it"
    set +e
    retry ${WAIT_FOR_RABBITMQ_MINUTES} 60 "is_rabbitmq_ready ${OPENSTACK_CONTROL_NODE_1_IP}"
    rc=$?
    set -e
    if ((${rc} == 0)); then
      echo "rabbitmq is ready, starting ${NUM_OPENSTACK_COMPUTE_NODES} compute(s)"
    else
      echo "rabbitmq was not ready in ${WAIT_FOR_RABBITMQ_MINUTES}m"
      exit 1
    fi
fi

for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
    COMPUTEIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    CONTROLIP=OPENSTACK_CONTROL_NODE_1_IP
    echo "Configure the stack of the compute node ${i} of ${NUM_OPENSTACK_COMPUTE_NODES}: ${!COMPUTEIP}"
    scp ${WORKSPACE}/disable_firewall.sh "${!COMPUTEIP}:/tmp"
    ${SSH} "${!COMPUTEIP}" "sudo bash /tmp/disable_firewall.sh"
    create_etc_hosts ${!COMPUTEIP} ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!COMPUTEIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
    ${SSH} ${!COMPUTEIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    create_compute_node_local_conf ${!COMPUTEIP} ${!CONTROLIP} ${ODLMGRIP} "${ODL_OVS_MGRS}"
    scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
    echo "Install rdo release to avoid incompatible Package versions"
    install_rdo_release ${!COMPUTEIP}
    setup_live_migration_compute ${!COMPUTEIP} ${!CONTROLIP}
    [ -n "${OVS_INSTALL}" ] && install_ovs ${!COMPUTEIP} /tmp/ovs_rpms
    if [[ "${ENABLE_OS_PLUGINS}" =~ networking-sfc ]]; then
        # This should be really done by networking-odl devstack plugin,
        # but in the meantime do it ourselves
        ssh ${!COMPUTEIP} "sudo ovs-vsctl set Open_vSwitch . external_ids:of-tunnel=true"
    fi
    fix_libvirt_python_build ${!COMPUTEIP}
    echo "Stack the compute node ${i} of ${NUM_OPENSTACK_COMPUTE_NODES}: ${!COMPUTEIP}"
    ssh ${!COMPUTEIP} "cd /opt/stack/devstack; nohup ./stack.sh > /opt/stack/devstack/nohup.out 2>&1 &"
    ssh ${!COMPUTEIP} "ps -ef | grep stack.sh"
    os_node_list+=("${!COMPUTEIP}")
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

# devstack debugging
# get_hostnames

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
        # devstack debugging
        # get_service "${iteration}" "${index}"
        if [ "$stacking_status" == "Still Stacking" ]; then
            continue
        elif [ "$stacking_status" == "Stacking Failed" ]; then
            echo "node $index ${os_node_list[index]}: stacking has failed"
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
        exit 1
    fi
done

# Further configuration now that stacking is complete.
echo "Configure the Control Node"
CONTROLIP=OPENSTACK_CONTROL_NODE_1_IP
# Gather Compute IPs for the site
for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
    IP_VAR=OPENSTACK_COMPUTE_NODE_${i}_IP
    COMPUTE_IPS[$((i-1))]=${!IP_VAR}
done

echo "sleep for 60s and print hypervisor-list"
sleep 60
${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; nova hypervisor-list"
# in the case that we are doing openstack (control + compute) all in one node, then the number of hypervisors
# will be the same as the number of openstack systems. However, if we are doing multinode openstack then the
# assumption is we have a single control node and the rest are compute nodes, so the number of expected hypervisors
# is one less than the total number of openstack systems
if [ ${NUM_OPENSTACK_SYSTEM} -eq 1 ]; then
    expected_num_hypervisors=1
else
    expected_num_hypervisors=${NUM_OPENSTACK_COMPUTE_NODES}
    if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
        expected_num_hypervisors=$((expected_num_hypervisors + 1))
    fi
fi
num_hypervisors=$(${SSH} ${!CONTROLIP} "cd /opt/stack/devstack; source openrc admin admin; openstack hypervisor list -f value | wc -l" | tail -1 | tr -d "\r")
if ! [ "${num_hypervisors}" ] || ! [ ${num_hypervisors} -eq ${expected_num_hypervisors} ]; then
    echo "Error: Only $num_hypervisors hypervisors detected, expected $expected_num_hypervisors"
    exit 1
fi

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
    # shellcheck disable=SC2206
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

get_test_suites SUITES

#install all client versions required for this job testing
install_openstack_clients_in_robot_vm

# TODO: run openrc on control node and then scrape the vars from it
# Environment Variables Needed to execute Openstack Client for NetVirt Jobs
cat > /tmp/os_netvirt_client_rc << EOF
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL="http://${!CONTROLIP}/identity"
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_TENANT_NAME=admin
unset OS_CLOUD
EOF

source /tmp/os_netvirt_client_rc

echo "Get all versions before executing robot"
echo "openstack --version"
which openstack
openstack --version
echo "nova --version"
which nova
nova --version
echo "neutron --version"
which neutron
neutron --version

stacktime=$(timer $totaltmr)
printf "Stacking elapsed time: %s\n" "${stacktime}"

echo "Starting Robot test suites ${SUITES} ..."
# please add robot -v arguments on a single line and alphabetized
suite_num=0
for suite in ${SUITES}; do
    # prepend an incremental counter to the suite name so that the full robot log combining all the suites as is done
    # in the rebot step below will list all the suites in chronological order as rebot seems to alphabetize them
    let "suite_num = suite_num + 1"
    suite_index="$(printf %02d ${suite_num})"
    suite_name="$(basename ${suite} | cut -d. -f1)"
    log_name="${suite_index}_${suite_name}"
    robot -N ${log_name} \
    -c critical -e exclude -e skip_if_${DISTROSTREAM} \
    --log log_${log_name}.html --report report_${log_name}.html --output output_${log_name}.xml \
    --removekeywords wuks \
    --removekeywords name:SetupUtils.Setup_Utils_For_Setup_And_Teardown \
    --removekeywords name:SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing \
    --removekeywords name:OpenStackOperations.Add_OVS_Logging_On_All_OpenStack_Nodes \
    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
    -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} \
    -v CMP_INSTANCES_SHARED_PATH:/var/instances \
    -v CONTROLLERFEATURES:"${CONTROLLERFEATURES}" \
    -v CONTROLLER_USER:${USER} \
    -v DEVSTACK_DEPLOY_PATH:/opt/stack/devstack \
    -v ENABLE_ITM_DIRECT_TUNNELS:${ENABLE_ITM_DIRECT_TUNNELS} \
    -v HA_PROXY_IP:${HA_PROXY_IP} \
    -v HA_PROXY_1_IP:${HA_PROXY_1_IP} \
    -v HA_PROXY_2_IP:${HA_PROXY_2_IP} \
    -v HA_PROXY_3_IP:${HA_PROXY_3_IP} \
    -v JDKVERSION:${JDKVERSION} \
    -v JENKINS_WORKSPACE:${WORKSPACE} \
    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
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
    -v OPENSTACK_TOPO:${OPENSTACK_TOPO} \
    -v OS_USER:${USER} \
    -v PUBLIC_PHYSICAL_NETWORK:${PUBLIC_PHYSICAL_NETWORK} \
    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
    -v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_1_IP:${TOOLS_SYSTEM_1_IP} \
    -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} \
    -v TOOLS_SYSTEM_3_IP:${TOOLS_SYSTEM_3_IP} \
    -v USER_HOME:${HOME} \
    -v WORKSPACE:/tmp \
    ${TESTOPTIONS} ${suite} || true
done
#rebot exit codes seem to be different
rebot --output ${WORKSPACE}/output.xml --log log_full.html --report report.html -N openstack output_*.xml || true

echo "Examining the files in data/log and checking file size"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
printf "Total elapsed time: %s, stacking time: %s\n" "$(timer $totaltmr)" "${stacktime}"
true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
