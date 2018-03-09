#!/bin/bash
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate
PYTHON="${ROBOT_VENV}/bin/python"
SSH="ssh -t -t"
ADMIN_PASSWORD="admin"
OPENSTACK_MASTER_CLIENTS_VERSION="queens"

# TODO: remove this work to run changes.py if/when it's moved higher up to be visible at the Robot level
printf "\nshowing recent changes that made it into the distribution used by this job:\n"
$PYTHON -m pip install --upgrade urllib3
python ${WORKSPACE}/test/tools/distchanges/changes.py -d /tmp/distribution_folder \
                  -u ${ACTUAL_BUNDLE_URL} -b ${DISTROBRANCH} \
                  -r ssh://jenkins-${SILO}@git.opendaylight.org:29418 || true

printf "\nshowing recent changes that made it into integration/test used by this job:\n"
cd ${WORKSPACE}/test
git --no-pager log --pretty=format:'%h %<(13)%ar%<(13)%cr %<(20,trunc)%an%d %s' -n10
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
    echo "trap_hanlder: ${prog}: line ${lastline}: exit status of last command: ${lasterr}"
    echo "trap_handler: command: ${BASH_COMMAND}"
    collect_logs
    exit 1
} # trap_handler()

trap 'trap_handler ${LINENO} ${$?}' ERR

function print_job_parameters() {
    cat << EOF

Job parameters:
DISTROBRANCH: ${DISTROBRANCH}
DISTROSTREAM: ${DISTROSTREAM}
BUNDLE_URL: ${BUNDLE_URL}
CONTROLLERFEATURES: ${CONTROLLERFEATURES}
CONTROLLERDEBUGMAP: ${CONTROLLERDEBUGMAP}
TESTPLAN: ${TESTPLAN}
SUITES: ${SUITES}
PATCHREFSPEC: ${PATCHREFSPEC}
OPENSTACK_BRANCH: ${OPENSTACK_BRANCH}
DEVSTACK_HASH: ${DEVSTACK_HASH}
ODL_ML2_DRIVER_REPO: ${ODL_ML2_DRIVER_REPO}
ODL_ML2_BRANCH: ${ODL_ML2_BRANCH}
ODL_ML2_DRIVER_VERSION: ${ODL_ML2_DRIVER_VERSION}
ODL_ML2_PORT_BINDING: ${ODL_ML2_PORT_BINDING}
DEVSTACK_KUBERNETES_PLUGIN_REPO: ${DEVSTACK_KUBERNETES_PLUGIN_REPO}
DEVSTACK_LBAAS_PLUGIN_REPO: ${DEVSTACK_LBAAS_PLUGIN_REPO}
DEVSTACK_NETWORKING_SFC_PLUGIN_REPO: ${DEVSTACK_NETWORKING_SFC_PLUGIN_REPO}
ODL_ENABLE_L3_FWD: ${ODL_ENABLE_L3_FWD}
IPSEC_VXLAN_TUNNELS_ENABLED: ${IPSEC_VXLAN_TUNNELS_ENABLED}
PUBLIC_BRIDGE: ${PUBLIC_BRIDGE}
ENABLE_HAPROXY_FOR_NEUTRON: ${ENABLE_HAPROXY_FOR_NEUTRON}
ENABLE_OS_SERVICES: ${ENABLE_OS_SERVICES}
ENABLE_OS_COMPUTE_SERVICES: ${ENABLE_OS_COMPUTE_SERVICES}
ENABLE_OS_NETWORK_SERVICES: ${ENABLE_OS_NETWORK_SERVICES}
ENABLE_OS_PLUGINS: ${ENABLE_OS_PLUGINS}
DISABLE_OS_SERVICES: ${DISABLE_OS_SERVICES}
TENANT_NETWORK_TYPE: ${TENANT_NETWORK_TYPE}
SECURITY_GROUP_MODE: ${SECURITY_GROUP_MODE}
PUBLIC_PHYSICAL_NETWORK: ${PUBLIC_PHYSICAL_NETWORK}
ENABLE_NETWORKING_L2GW: ${ENABLE_NETWORKING_L2GW}
CREATE_INITIAL_NETWORKS: ${CREATE_INITIAL_NETWORKS}
LBAAS_SERVICE_PROVIDER: ${LBAAS_SERVICE_PROVIDER}
NUM_OPENSTACK_SITES: ${NUM_OPENSTACK_SITES}
ODL_SFC_DRIVER: ${ODL_SFC_DRIVER}
ODL_SNAT_MODE: ${ODL_SNAT_MODE}

EOF
}

print_job_parameters

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

#function to install Openstack Clients for Testing
#This will pull the latest versions compatiable with the
# openstack release
function install_openstack_clients_in_robot_vm() {
    packages=("python-novaclient" "python-neutronclient" "python-openstackclient")
    for plugin_name in ${ENABLE_OS_PLUGINS}; do
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
        #networking-l2gw is not officially available in any release yet. Gettting the latest stable version.
        $PYTHON -m pip install networking-l2gw==11.0.0
    fi
}

# convert commas in csv strings to spaces (ssv)
function csv2ssv() {
    local csv=$1
    if [ -n "${csv}" ]; then
        ssv=$(echo ${csv} | sed 's/,/ /g' | sed 's/\ \ */\ /g')
    fi

    echo "${ssv}"
} # csv2ssv

function is_openstack_feature_enabled() {
    local feature=$1
    for enabled_feature in $(csv2ssv ${ENABLE_OS_SERVICES})
    do
        if [ "${enabled_feature}" == "${feature}" ]; then
           echo 1
           return
        fi
    done
    echo 0
}

function fix_libvirt_version_n_cpu_ocata() {
    local ip=$1
    ${SSH} ${ip} "
        cd /opt/stack;
        git clone https://git.openstack.org/openstack/requirements;
        cd requirements;
        git checkout stable/ocata;
        sed -i s/libvirt-python===2.5.0/libvirt-python===3.2.0/ upper-constraints.txt
   "
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
USE_SCREEN=True
SCREEN_LOGDIR=/opt/stack/data/log
LOG_COLOR=False
RECLONE=${RECLONE}

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
# MTU(1400) + VXLAN(50) + VLAN(4) = 1454 < MTU eth0/br-physnet1(1458)
physical_network_mtus = ${PUBLIC_PHYSICAL_NETWORK}:1400
path_mtu = 1458

[[post-config|/etc/neutron/dhcp_agent.ini]]
[DEFAULT]
force_metadata = True
enable_isolated_metadata = True

[[post-config|/etc/nova/nova.conf]]
[DEFAULT]
force_config_drive = False
force_raw_images = False

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

    add_os_services "${CORE_OS_COMPUTE_SERVICES}" "${ENABLE_OS_COMPUTE_SERVICES}" "${DISABLE_OS_SERVICES}" "${local_conf_file_name}"

    cat >> ${local_conf_file_name} << EOF
#Added to make Nova wait until nova in control node is ready.
NOVA_READY_TIMEOUT=1800
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
force_raw_images = False
EOF

    echo "Compute local.conf created:"
    cat ${local_conf_file_name}
} # create_compute_node_local_conf()

function configure_haproxy_for_neutron_requests() {
    MGRIP=$1
    # shellcheck disable=SC2206
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

# Collect the list of files on the hosts
function collect_files() {
    local -r ip=$1
    local -r folder=$2
    finddir=/tmp/finder
    ${SSH} ${ip} "mkdir -p ${finddir}"
    ${SSH} ${ip} "sudo find /etc > ${finddir}/find.etc.txt"
    ${SSH} ${ip} "sudo find /opt/stack > ${finddir}/find.opt.stack.txt"
    ${SSH} ${ip} "sudo find /var > ${finddir}/find2.txt"
    ${SSH} ${ip} "sudo find /var > ${finddir}/find.var.txt"
    ${SSH} ${ip} "sudo tar -cf - -C /tmp finder | xz -T 0 > /tmp/find.tar.xz"
    scp ${ip}:/tmp/find.tar.xz ${folder}
    mkdir -p ${finddir}
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh ${ip}:/etc/ > ${finddir}/rsync.etc.txt
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh ${ip}:/opt/stack/ > ${finddir}/rsync.opt.stack.txt
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh ${ip}:/var/ > ${finddir}/rsync.var.txt
    tar -cf - -C /tmp finder | xz -T 0 > /tmp/rsync.tar.xz
    cp /tmp/rsync.tar.xz ${folder}
}

declare -a os_services=(
    "devstack@g-api.service"
    "devstack@g-reg.service"
    "devstack@keystone.service"
    "devstack@n-api-meta.service"
    "devstack@n-api.service"
    "devstack@n-cauth.service"
    "devstack@n-cond-cell1.service"
    "devstack@n-cpu.service"
    "devstack@n-novnc.service"
    "devstack@n-sch.service"
    "devstack@n-super-cond.service"
    "devstack@n-xvnc.service"
    "devstack@neutron-api.service"
    "devstack@neutron-dhcp.service"
    "devstack@placement-api.service"
)

# Collect the logs for the openstack services
function collect_openstack_logs() {
    local -r ip=${1}
    local -r folder=${2}
    local oslogs="${folder}/oslogs"

    printf "collect_openstack_logs for node: ${ip} into ${oslogs}\n"
    mkdir -p ${oslogs}
    # There are always some logs in /opt/stack/logs and this also covers the
    # pre-queens branches which always use /opt/stack/logs
    rsync -avhe ssh ${ip}:/opt/stack/logs/* ${oslogs} # rsync to prevent copying of symbolic links

    # Starting with queens break out the logs from journalctl
    if [ "${OPENSTACK_BRANCH}" = "stable/queens" ]; then
        cat > ${WORKSPACE}/collect_openstack_logs.sh << EOF
mkdir -p /tmp/oslogs
for svc in ${os_services[@]}; do
    svc_="\${svc:9}"
    journalctl -u "\${svc}" > "/tmp/oslogs/\${svc_}.log"
done
ls -al /tmp/oslogs
systemctl list-unit-files --all
EOF
        scp ${WORKSPACE}/collect_openstack_logs.sh ${ip}:/tmp
        printf "collect_openstack_logs for node: ${ip} into ${oslogs}, executing script\n"
        #${SSH} ${ip} "bash ${WORKSPACE}/collect_openstack_logs.sh > /tmp/oslogs/collect_openstack_logs.log"
        ${SSH} ${ip} "bash ${WORKSPACE}/collect_openstack_logs.sh > /tmp/collect_openstack_logs.log 2>&1"
        rsync -avhe ssh ${ip}:/tmp/oslogs/* ${oslogs}
        scp ${ip}:/tmp/collect_openstack_logs.log ${NODE_FOLDER}
    fi
}

function collect_logs() {
    set +e  # We do not want to create red dot just because something went wrong while fetching logs.

    cat > extra_debug.sh << EOF
echo -e "/usr/sbin/lsmod | /usr/bin/grep openvswitch\n"
/usr/sbin/lsmod | /usr/bin/grep openvswitch
echo -e "\nsudo grep ct_ /var/log/openvswitch/ovs-vswitchd.log\n"
sudo grep "Datapath supports" /var/log/openvswitch/ovs-vswitchd.log
echo -e "\nsudo netstat -punta\n"
sudo netstat -punta
echo -e "\nsudo getenforce\n"
sudo getenforce
echo -e "\nsudo systemctl status httpd\n"
sudo systemctl status httpd
echo -e "\nenv\n"
env
source /opt/stack/devstack/openrc admin admin
echo -e "\nenv after openrc\n"
env
echo -e "\nsudo du -hs /opt/stack"
sudo du -hs /opt/stack
echo -e "\nsudo mount"
sudo mount
echo -e "\ndmesg -T > /tmp/dmesg.log"
dmesg -T > /tmp/dmesg.log
echo -e "\njournalctl > /tmp/journalctl.log\n"
sudo journalctl > /tmp/journalctl.log
echo -e "\novsdb-tool -mm show-log > /tmp/ovsdb-tool.log"
ovsdb-tool -mm show-log > /tmp/ovsdb-tool.log
EOF

    # Since this log collection work is happening before the archive build macro which also
    # creates the ${WORKSPACE}/archives dir, we have to do it here first.  The mkdir in the
    # archives build step will essentially be a noop.
    mkdir -p ${WORKSPACE}/archives

    mv /tmp/changes.txt ${WORKSPACE}/archives
    mv ${WORKSPACE}/rabbit.txt ${WORKSPACE}/archives

    sleep 5
    # FIXME: Do not create .tar and gzip before copying.
    for i in `seq 1 ${NUM_ODL_SYSTEM}`; do
        CONTROLLERIP=ODL_SYSTEM_${i}_IP
        echo "collect_logs: for opendaylight controller ip: ${!CONTROLLERIP}"
        NODE_FOLDER="odl_${i}"
        mkdir -p ${NODE_FOLDER}
        echo "Lets's take the karaf thread dump again..."
        ssh ${!CONTROLLERIP} "sudo ps aux" > ${WORKSPACE}/ps_after.log
        pid=$(grep org.apache.karaf.main.Main ${WORKSPACE}/ps_after.log | grep -v grep | tr -s ' ' | cut -f2 -d' ')
        echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
        ssh ${!CONTROLLERIP} "jstack ${pid}" > ${WORKSPACE}/karaf_${i}_${pid}_threads_after.log || true
        echo "killing karaf process..."
        ${SSH} "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
        ${SSH} ${!CONTROLLERIP} "sudo journalctl > /tmp/journalctl.log"
        scp ${!CONTROLLERIP}:/tmp/journalctl.log ${NODE_FOLDER}
        ${SSH} ${!CONTROLLERIP} "dmesg -T > /tmp/dmesg.log"
        scp ${!CONTROLLERIP}:/tmp/dmesg.log ${NODE_FOLDER}
        ${SSH} ${!CONTROLLERIP} "tar -cf - -C /tmp/${BUNDLEFOLDER} etc | xz -T 0 > /tmp/etc.tar.xz"
        scp ${!CONTROLLERIP}:/tmp/etc.tar.xz ${NODE_FOLDER}
        ${SSH} ${!CONTROLLERIP} "cp -r /tmp/${BUNDLEFOLDER}/data/log /tmp/odl_log"
        ${SSH} ${!CONTROLLERIP} "tar -cf /tmp/odl${i}_karaf.log.tar /tmp/odl_log/*"
        scp ${!CONTROLLERIP}:/tmp/odl${i}_karaf.log.tar ${NODE_FOLDER}
        ${SSH} ${!CONTROLLERIP} "tar -cf /tmp/odl${i}_zrpcd.log.tar /tmp/zrpcd.init.log"
        scp ${!CONTROLLERIP}:/tmp/odl${i}_zrpcd.log.tar ${NODE_FOLDER}
        tar -xvf ${NODE_FOLDER}/odl${i}_karaf.log.tar -C ${NODE_FOLDER} --strip-components 2 --transform s/karaf/odl${i}_karaf/g
        grep "ROBOT MESSAGE\| ERROR " ${NODE_FOLDER}/odl${i}_karaf.log > ${NODE_FOLDER}/odl${i}_err.log
        grep "ROBOT MESSAGE\| ERROR \| WARN \|Exception" \
            ${NODE_FOLDER}/odl${i}_karaf.log > ${NODE_FOLDER}/odl${i}_err_warn_exception.log
        # Print ROBOT lines and print Exception lines. For exception lines also print the previous line for context
        sed -n -e '/ROBOT MESSAGE/P' -e '$!N;/Exception/P;D' ${NODE_FOLDER}/odl${i}_karaf.log > ${NODE_FOLDER}/odl${i}_exception.log
        rm ${NODE_FOLDER}/odl${i}_karaf.log.tar
        mv *_threads* ${NODE_FOLDER}
        mv ps_* ${NODE_FOLDER}
        mv ${NODE_FOLDER} ${WORKSPACE}/archives/
    done

    print_job_parameters > ${WORKSPACE}/archives/params.txt

    # Control Node
    for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
        OSIP=OPENSTACK_CONTROL_NODE_${i}_IP
        echo "collect_logs: for openstack control node ip: ${!OSIP}"
        NODE_FOLDER="control_${i}"
        mkdir -p ${NODE_FOLDER}
        scp extra_debug.sh ${!OSIP}:/tmp
        ${SSH} ${!OSIP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log 2>&1"
        scp ${!OSIP}:/etc/dnsmasq.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/keystone/keystone.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/keystone/keystone-uwsgi-admin.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/keystone/keystone-uwsgi-public.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/kuryr/kuryr.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/dhcp_agent.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/metadata_agent.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/neutron.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/neutron_lbaas.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/plugins/ml2/ml2_conf.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/neutron/services/loadbalancer/haproxy/lbaas_agent.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova-api-uwsgi.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova_cell1.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova-cpu.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/placement-uwsgi.ini ${NODE_FOLDER}
        scp ${!OSIP}:/etc/openstack/clouds.yaml ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/devstack/.stackenv ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/devstack/nohup.out ${NODE_FOLDER}/stack.log
        scp ${!OSIP}:/opt/stack/devstack/openrc ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/requirements/upper-constraints.txt ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/tempest/etc/tempest.conf ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/*.xz ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/dmesg.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/extra_debug.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/get_devstack.sh.txt ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/journalctl.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/ovsdb-tool.log ${NODE_FOLDER}
        collect_files "${!OSIP}" "${NODE_FOLDER}"
        ${SSH} ${!OSIP} "sudo tar -cf - -C /var/log rabbitmq | xz -T 0 > /tmp/rabbitmq.tar.xz "
        scp ${!OSIP}:/tmp/rabbitmq.tar.xz ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/etc/hosts ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/usr/lib/systemd/system/haproxy.service ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/audit/audit.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/httpd/keystone_access.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/httpd/keystone.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/messages* ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/openvswitch/ovs-vswitchd.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/openvswitch/ovsdb-server.log ${NODE_FOLDER}
        collect_openstack_logs ${!OSIP} ${NODE_FOLDER}
        mv local.conf_control_${!OSIP} ${NODE_FOLDER}/local.conf
        # qdhcp files are created by robot tests and copied into /tmp/qdhcp during the test
        tar -cf - -C /tmp qdhcp | xz -T 0 > /tmp/qdhcp.tar.xz
        mv /tmp/qdhcp.tar.xz ${NODE_FOLDER}
        mv ${NODE_FOLDER} ${WORKSPACE}/archives/
    done

    # Compute Nodes
    for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
        OSIP=OPENSTACK_COMPUTE_NODE_${i}_IP
        echo "collect_logs: for openstack compute node ip: ${!OSIP}"
        NODE_FOLDER="compute_${i}"
        mkdir -p ${NODE_FOLDER}
        scp extra_debug.sh ${!OSIP}:/tmp
        ${SSH} ${!OSIP} "bash /tmp/extra_debug.sh > /tmp/extra_debug.log 2>&1"
        scp ${!OSIP}:/etc/nova/nova.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/nova/nova-cpu.conf ${NODE_FOLDER}
        scp ${!OSIP}:/etc/openstack/clouds.yaml ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/devstack/.stackenv ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/devstack/nohup.out ${NODE_FOLDER}/stack.log
        scp ${!OSIP}:/opt/stack/devstack/openrc ${NODE_FOLDER}
        scp ${!OSIP}:/opt/stack/requirements/upper-constraints.txt ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/*.xz ${NODE_FOLDER}/
        scp ${!OSIP}:/tmp/dmesg.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/extra_debug.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/get_devstack.sh.txt ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/journalctl.log ${NODE_FOLDER}
        scp ${!OSIP}:/tmp/ovsdb-tool.log ${NODE_FOLDER}
        collect_files "${!OSIP}" "${NODE_FOLDER}"
        ${SSH} ${!OSIP} "sudo tar -cf - -C /var/log libvirt | xz -T 0 > /tmp/libvirt.tar.xz "
        scp ${!OSIP}:/tmp/libvirt.tar.xz ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/etc/hosts ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/audit/audit.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/messages* ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/nova-agent.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/openvswitch/ovs-vswitchd.log ${NODE_FOLDER}
        rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/openvswitch/ovsdb-server.log ${NODE_FOLDER}
        collect_openstack_logs ${!OSIP} ${NODE_FOLDER}
        mv local.conf_compute_${!OSIP} ${NODE_FOLDER}/local.conf
        mv ${NODE_FOLDER} ${WORKSPACE}/archives/
    done

    # Tempest
    DEVSTACK_TEMPEST_DIR="/opt/stack/tempest"
    TESTREPO=".stestr"
    TEMPEST_LOGS_DIR=${WORKSPACE}/archives/tempest
    # Look for tempest test results in the $TESTREPO dir and copy if found
    if ${SSH} ${OPENSTACK_CONTROL_NODE_1_IP} "sudo sh -c '[ -f ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/0 ]'"; then
        ${SSH} ${OPENSTACK_CONTROL_NODE_1_IP} "for I in \$(sudo ls ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/ | grep -E '^[0-9]+$'); do sudo sh -c \"${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/subunit-1to2 < ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/\${I} >> ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt\"; done"
        ${SSH} ${OPENSTACK_CONTROL_NODE_1_IP} "sudo sh -c '${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/python ${DEVSTACK_TEMPEST_DIR}/.tox/tempest/lib/python2.7/site-packages/os_testr/subunit2html.py ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt ${DEVSTACK_TEMPEST_DIR}/tempest_results.html'"
        mkdir -p ${TEMPEST_LOGS_DIR}
        scp ${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest_results.html ${TEMPEST_LOGS_DIR}
        scp ${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest.log ${TEMPEST_LOGS_DIR}
        if [ "$(echo ${OPENSTACK_BRANCH} | cut -d/ -f2)" != "queens" ]; then
           mv ${WORKSPACE}/tempest_output* ${TEMPEST_LOGS_DIR}
        fi
    else
        echo "tempest results not found in ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/0"
    fi
} # collect_logs()

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
    if [ "${OPENSTACK_BRANCH}" == "stable/ocata" ]; then
        ${SSH} ${ip} "sudo rabbitmqctl status" > rabbit.txt
        grepfor="pid"
    else
        ${SSH} ${ip} "sudo rabbitmqctl list_vhosts" > rabbit.txt
    fi
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
sudo mount -t tmpfs -o size=2G tmpfs /opt/stack
sudo chmod 777 /opt/stack
cd /opt/stack
echo "git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}"
git clone https://git.openstack.org/openstack-dev/devstack --branch ${OPENSTACK_BRANCH}
cd devstack
if [ -n "${DEVSTACK_HASH}" ]; then
    echo "git checkout ${DEVSTACK_HASH}"
    git checkout ${DEVSTACK_HASH}
fi
echo "workaround: Restore NEUTRON_CREATE_INITIAL_NETWORKS flag"
if [ "${OPENSTACK_BRANCH}" == "stable/queens" ]; then
    git config --local user.email jenkins@opendaylight.org
    git config --local user.name jenkins
    git fetch https://git.openstack.org/openstack-dev/devstack refs/changes/99/550499/1 && git cherry-pick FETCH_HEAD
fi
git --no-pager log --pretty=format:'%h %<(13)%ar%<(13)%cr %<(20,trunc)%an%d %s%b' -n20
echo
echo "workaround: adjust wait from 60s to 1800s (30m)"
sed -i 's/wait_for_compute 60/wait_for_compute 1800/g' /opt/stack/devstack/lib/nova
# TODO: modify sleep 1 to sleep 60, search wait_for_compute, then first sleep 1
# that would just reduce the number of logs in the compute stack.log

#Install qemu-img command in Control Node for Pike
echo "Install qemu-img application"
sudo yum install -y qemu-img
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
    echo "Configure the stack of the control node ${i} of ${NUM_OPENSTACK_CONTROL_NODES}: ${!CONTROLIP}"
    scp ${WORKSPACE}/disable_firewall.sh ${!CONTROLIP}:/tmp
    ${SSH} ${!CONTROLIP} "sudo bash /tmp/disable_firewall.sh"
    create_etc_hosts ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!CONTROLIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh ${!CONTROLIP}:/tmp
    # devstack Master is yet to migrate fully to lib/neutron, there are some ugly hacks that is
    # affecting the stacking.
    #Workaround For Queens, Make the physical Network as physnet1 in lib/neutron
    #Workaround Comment out creating initial Networks in lib/neutron
    ${SSH} ${!CONTROLIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    if [ "${ODL_ML2_BRANCH}" == "stable/queens" ]; then
       ssh ${!CONTROLIP} "sed -i 's/flat_networks public/flat_networks public,physnet1/' /opt/stack/devstack/lib/neutron"
       ssh ${!CONTROLIP} "sed -i '186i iniset \$NEUTRON_CORE_PLUGIN_CONF ml2_type_vlan network_vlan_ranges public:1:4094,physnet1:1:4094' /opt/stack/devstack/lib/neutron"
    fi
    if [[ "${ODL_ML2_BRANCH}" == "stable/ocata" && "$(is_openstack_feature_enabled n-cpu)" == "1" ]]; then
        echo "Updating requirements for ${ODL_ML2_BRANCH}"
        echo "Workaround for https://review.openstack.org/#/c/491032/"
        echo "Modify upper-constraints to use libvirt-python 3.2.0"
        fix_libvirt_version_n_cpu_ocata ${!CONTROLIP}
    fi
    create_control_node_local_conf ${!CONTROLIP} ${ODLMGRIP[$i]} "${ODL_OVS_MGRS[$i]}"
    scp ${WORKSPACE}/local.conf_control_${!CONTROLIP} ${!CONTROLIP}:/opt/stack/devstack/local.conf
    echo "Stack the control node ${i} of ${NUM_OPENSTACK_CONTROL_NODES}: ${CONTROLIP}"
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
      collect_logs
      exit 1
    fi
fi

for i in `seq 1 ${NUM_OPENSTACK_COMPUTE_NODES}`; do
    NUM_COMPUTES_PER_SITE=$((NUM_OPENSTACK_COMPUTE_NODES / NUM_OPENSTACK_SITES))
    SITE_INDEX=$((((i - 1) / NUM_COMPUTES_PER_SITE) + 1)) # We need the site index to infer the control node IP for this compute
    COMPUTEIP=OPENSTACK_COMPUTE_NODE_${i}_IP
    CONTROLIP=OPENSTACK_CONTROL_NODE_${SITE_INDEX}_IP
    echo "Configure the stack of the compute node ${i} of ${NUM_OPENSTACK_COMPUTE_NODES}: ${!COMPUTEIP}"
    scp ${WORKSPACE}/disable_firewall.sh "${!COMPUTEIP}:/tmp"
    ${SSH} "${!COMPUTEIP}" "sudo bash /tmp/disable_firewall.sh"
    create_etc_hosts ${!COMPUTEIP} ${!CONTROLIP}
    scp ${WORKSPACE}/hosts_file ${!COMPUTEIP}:/tmp/hosts
    scp ${WORKSPACE}/get_devstack.sh  ${!COMPUTEIP}:/tmp
    ${SSH} ${!COMPUTEIP} "bash /tmp/get_devstack.sh > /tmp/get_devstack.sh.txt 2>&1"
    if [ "${ODL_ML2_BRANCH}" == "stable/ocata" ]; then
        echo "Updating requirements for ${ODL_ML2_BRANCH}"
        echo "Workaround for https://review.openstack.org/#/c/491032/"
        echo "Modify upper-constraints to use libvirt-python 3.2.0"
        fix_libvirt_version_n_cpu_ocata ${!COMPUTEIP}
    fi
    create_compute_node_local_conf ${!COMPUTEIP} ${!CONTROLIP} ${ODLMGRIP[$SITE_INDEX]} "${ODL_OVS_MGRS[$SITE_INDEX]}"
    scp ${WORKSPACE}/local.conf_compute_${!COMPUTEIP} ${!COMPUTEIP}:/opt/stack/devstack/local.conf
    echo "Stack the compute node ${i} of ${NUM_OPENSTACK_COMPUTE_NODES}: ${COMPUTEIP}"
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

    echo "sleep for 60s and print hypervisor-list"
    sleep 60
    # In Ocata if we do not enable the n-cpu in control node then
    # we need to discover hosts manually and ensure that they are mapped to cells.
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
else
    newsuites=""
    workpath="${WORKSPACE}/test/csit/suites"
    for suite in ${SUITES}; do
        fullsuite="${workpath}/${suite}"
        if [ -z "${newsuites}" ]; then
            newsuites+=${fullsuite}
        else
            newsuites+=" "${fullsuite}
        fi
    done
    SUITES=${newsuites}
fi

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

echo "Get all versions before executing pybot"
echo "openstack --version"
which openstack
openstack --version
echo "nova --version"
which nova
nova --version
echo "neutron --version"
which neutron
neutron --version

echo "Starting Robot test suites ${SUITES} ..."
# please add pybot -v arguments on a single line and alphabetized
suite_num=0
for suite in ${SUITES}; do
    # prepend an incremental counter to the suite name so that the full robot log combining all the suites as is done
    # in the rebot step below will list all the suites in chronological order as rebot seems to alphabetize them
    let "suite_num = suite_num + 1"
    suite_index="$(printf %02d ${suite_num})"
    suite_name="$(basename ${suite} | cut -d. -f1)"
    log_name="${suite_index}_${suite_name}"
    pybot -N ${log_name} \
    -c critical -e exclude -e skip_if_${DISTROSTREAM} \
    --log log_${log_name}.html --report None --output output_${log_name}.xml \
    --removekeywords wuks \
    --removekeywords name:SetupUtils.Setup_Utils_For_Setup_And_Teardown \
    --removekeywords name:SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing \
    --removekeywords name:OpenStackOperations.Add_OVS_Logging_On_All_OpenStack_Nodes \
    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
    -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} \
    -v CONTROLLERFEATURES:"${CONTROLLERFEATURES}" \
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
    -v ODL_ENABLE_L3_FWD:${ODL_ENABLE_L3_FWD} \
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
    ${TESTOPTIONS} ${suite} || true
done
#rebot exit codes seem to be different
rebot --output ${WORKSPACE}/output.xml --log log_full.html --report None -N openstack output_*.xml || true

echo "Examining the files in data/log and checking file size"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
collect_logs

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
