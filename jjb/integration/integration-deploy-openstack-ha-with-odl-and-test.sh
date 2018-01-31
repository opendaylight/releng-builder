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
##         Deploy Openstack from RPMs          ##
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
ODL_ML2_DRIVER_NAME: ${ODL_ML2_DRIVER_NAME}
ODL_ML2_PORT_BINDING: ${ODL_ML2_PORT_BINDING}
ODL_ENABLE_L3_FWD: ${ODL_ENABLE_L3_FWD}
IPSEC_VXLAN_TUNNELS_ENABLED: ${IPSEC_VXLAN_TUNNELS_ENABLED}
PUBLIC_BRIDGE: ${PUBLIC_BRIDGE}
ENABLE_HAPROXY_FOR_NEUTRON: ${ENABLE_HAPROXY_FOR_NEUTRON}
DISABLE_OS_SERVICES: ${DISABLE_OS_SERVICES}
TENANT_NETWORK_TYPE: ${TENANT_NETWORK_TYPE}
SECURITY_GROUP_MODE: ${SECURITY_GROUP_MODE}
PUBLIC_PHYSICAL_NETWORK: ${PUBLIC_PHYSICAL_NETWORK}
ENABLE_NETWORKING_L2GW: ${ENABLE_NETWORKING_L2GW}
NUM_OPENSTACK_SITES: ${NUM_OPENSTACK_SITES}
ODL_SNAT_MODE: ${ODL_SNAT_MODE}

EOF
}

print_job_parameters


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

function create_etc_hosts() {
    for i in $(seq 1 ${NUM_OPENSTACK_NEW_NODES})
    do
        IP=OPENSTACK_NEW_NODE_${i}_IP
        HOST=OPENSTACK_NEW_NODE_${i}_HOSTNAME
        echo ${!IP}    ${!HOST} >> ${WORKSPACE}/hosts
    done
    echo $(dig +short nexus01.dfw.opendaylight.org) nexus01.dfw.opendaylight.org >> ${WORKSPACE}/hosts
    echo $(dig +short nexus02.dfw.opendaylight.org) nexus02.dfw.opendaylight.org >> ${WORKSPACE}/hosts
    echo $(dig +short nexus03.ord.opendaylight.org) nexus03.ord.opendaylight.org >> ${WORKSPACE}/hosts
}

create_etc_hosts

function start_all_basic_os_services() {
    local control_ip=${1}
    local control_hostname=${2}
    scp ${WORKSPACE}/hosts  ${control_ip}:/tmp/hosts
    ${SSH} ${control_ip} "sudo mv /tmp/hosts /etc/hosts"
    ${SSH} ${control_ip} "sudo systemctl start chrony memcached;sudo systemctl status chrony memcached"
    echo "Start The Mysql"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_mysql.sh"
    echo "Start Rabbit Server"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_rabbit.sh"
    echo "Start Identity"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_keystone.sh ${control_hostname}"
    echo "Create Service and Domain"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/create_domain_service.sh ${control_hostname}"
    echo "Start Glance"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_glance.sh ${control_hostname}"
    echo "Start Nova Services"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_nova_core.sh ${control_ip} ${control_hostname}"
    echo "Start Neutron DB Services"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_neutron_db.sh ${control_hostname}"
    echo "Configure Neutron"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/setup_neutron_server.sh ${control_hostname} ${TENANT_NETWORK_TYPE}"
    echo "Load Images"
    ${SSH} ${control_ip} "bash -x /opt/openstack/install/load_images_flavors.sh"
}

function configure_all_compute_services() {
    local compute_ip=${1}
    local control_hostname=${2}
    scp ${WORKSPACE}/hosts  ${compute_ip}:/tmp/hosts
    ${SSH} ${compute_ip} "sudo mv /tmp/hosts /etc/hosts"
    ${SSH} ${compute_ip} "bash -x /opt/openstack/install/setup_neutron_server.sh ${control_hostname} ${TENANT_NETWORK_TYPE}"
    ${SSH} ${compute_ip} "bash -x /opt/openstack/install/setup_nova_compute.sh ${control_hostname} ${compute_ip}"
}

#start_all_basic_os_services ${OPENSTACK_NEW_NODE_1_IP} ${OPENSTACK_NEW_NODE_1_HOSTNAME}
#configure_all_compute_services ${OPENSTACK_NEW_NODE_2_IP} ${OPENSTACK_NEW_NODE_1_HOSTNAME}
#configure_all_compute_services ${OPENSTACK_NEW_NODE_3_IP} ${OPENSTACK_NEW_NODE_1_HOSTNAME}



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

pybot --debug install_reports.log \
  -v NUM_CONTROL_NODES:1 \
  -v NUM_COMPUTE_NODES:2 \
  -v NUM_NEUTRON_NODES:3 \
  -v OS_CONTROL_1_IP:${OPENSTACK_NEW_NODE_1_IP} \
  -v OS_CONTROL_1_HOSTNAME:${OPENSTACK_NEW_NODE_1_HOSTNAME} \
  -v OS_COMPUTE_1_IP:${OPENSTACK_NEW_NODE_2_IP} \
  -v OS_COMPUTE_1_HOSTNAME:${OPENSTACK_NEW_NODE_2_HOSTNAME} \
  -v OS_COMPUTE_2_IP:${OPENSTACK_NEW_NODE_3_IP} \
  -v OS_COMPUTE_2_HOSTNAME:${OPENSTACK_NEW_NODE_3_HOSTNAME} \
  -v OS_NEUTRON_1_IP:${OPENSTACK_NEW_NODE_1_IP} \
  -v OS_NEUTRON_1_HOSTNAME:${OPENSTACK_NEW_NODE_1_HOSTNAME} \
  -v OS_NEUTRON_2_IP:${OPENSTACK_NEW_NODE_2_IP} \
  -v OS_NEUTRON_2_HOSTNAME:${OPENSTACK_NEW_NODE_2_HOSTNAME} \
  -v OS_NEUTRON_3_IP:${OPENSTACK_NEW_NODE_3_IP} \
  -v OS_NEUTRON_3_HOSTNAME:${OPENSTACK_NEW_NODE_3_HOSTNAME} \
  -v OPENSTACK_VERSION:pike \
  -v OS_USER:jenkins \
  -v OS_USER_PASSWORD: \
  -v OS_APPS_PRE_INSTALLED:yes \
  -v UPGRADE_REQUIRED:no \
  -v ODL_RPM:https://nexus.opendaylight.org/content/repositories/opendaylight-nitrogen-epel-7-x86_64-devel/org/opendaylight/integration-packaging/opendaylight/7.3.0-0.1.20180423snap279.el7.noarch/opendaylight-7.3.0-0.1.20180423snap279.el7.noarch.rpm \
  -v ODL_NETVIRT_SNAT_MODE:conntrack \
  -v USER_HOME:/home/jenkins \
  -v ODL_INSTALL_LOCAL_RPM:no \
  -v ODL_NW_RPM:python-networking-odl \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/00_initial_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/01_mysql_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/02_rabbitmq_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/03_keystone_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/04_glance_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/05_nova_setup.robot \
  ${WORKSPACE}/test/tools/deployment/openstack_ha/deploy/06_neutron_setup.robot

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

openstack network list

#echo "Starting Robot test suites ${SUITES} ..."
## please add pybot -v arguments on a single line and alphabetized
#suite_num=0
#for suite in ${SUITES}; do
#    # prepend an incremental counter to the suite name so that the full robot log combining all the suites as is done
#    # in the rebot step below will list all the suites in chronological order as rebot seems to alphabetize them
#    let "suite_num = suite_num + 1"
#    suite_index="$(printf %02d ${suite_num})"
#    suite_name="$(basename ${suite} | cut -d. -f1)"
#    log_name="${suite_index}_${suite_name}"
#    pybot -N ${log_name} \
#    -c critical -e exclude -e skip_if_${DISTROSTREAM} \
#    --log log_${log_name}.html --report None --output output_${log_name}.xml \
#    --removekeywords wuks \
#    --removekeywords name:SetupUtils.Setup_Utils_For_Setup_And_Teardown \
#    --removekeywords name:SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing \
#    --removekeywords name:OpenStackOperations.Add_OVS_Logging_On_All_OpenStack_Nodes \
#    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
#    -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} \
#    -v CONTROLLERFEATURES:"${CONTROLLERFEATURES}" \
#    -v CONTROLLER_USER:${USER} \
#    -v DEVSTACK_DEPLOY_PATH:/opt/stack/devstack \
#    -v HA_PROXY_IP:${HA_PROXY_IP} \
#    -v HA_PROXY_1_IP:${HA_PROXY_1_IP} \
#    -v HA_PROXY_2_IP:${HA_PROXY_2_IP} \
#    -v HA_PROXY_3_IP:${HA_PROXY_3_IP} \
#    -v JDKVERSION:${JDKVERSION} \
#    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
#    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
#    -v NUM_OPENSTACK_SITES:${NUM_OPENSTACK_SITES} \
#    -v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} \
#    -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
#    -v ODL_SNAT_MODE:${ODL_SNAT_MODE} \
#    -v ODL_ENABLE_L3_FWD:${ODL_ENABLE_L3_FWD} \
#    -v ODL_STREAM:${DISTROSTREAM} \
#    -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
#    -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} \
#    -v ODL_SYSTEM_2_IP:${ODL_SYSTEM_2_IP} \
#    -v ODL_SYSTEM_3_IP:${ODL_SYSTEM_3_IP} \
#    -v ODL_SYSTEM_4_IP:${ODL_SYSTEM_4_IP} \
#    -v ODL_SYSTEM_5_IP:${ODL_SYSTEM_5_IP} \
#    -v ODL_SYSTEM_6_IP:${ODL_SYSTEM_6_IP} \
#    -v ODL_SYSTEM_7_IP:${ODL_SYSTEM_7_IP} \
#    -v ODL_SYSTEM_8_IP:${ODL_SYSTEM_8_IP} \
#    -v ODL_SYSTEM_9_IP:${ODL_SYSTEM_9_IP} \
#    -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
#    -v OS_CONTROL_NODE_1_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
#    -v OS_CONTROL_NODE_2_IP:${OPENSTACK_CONTROL_NODE_2_IP} \
#    -v OS_CONTROL_NODE_3_IP:${OPENSTACK_CONTROL_NODE_3_IP} \
#    -v OPENSTACK_BRANCH:${OPENSTACK_BRANCH} \
#    -v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} \
#    -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
#    -v OS_COMPUTE_3_IP:${OPENSTACK_COMPUTE_NODE_3_IP} \
#    -v OS_COMPUTE_4_IP:${OPENSTACK_COMPUTE_NODE_4_IP} \
#    -v OS_COMPUTE_5_IP:${OPENSTACK_COMPUTE_NODE_5_IP} \
#    -v OS_COMPUTE_6_IP:${OPENSTACK_COMPUTE_NODE_6_IP} \
#    -v OS_USER:${USER} \
#    -v PUBLIC_PHYSICAL_NETWORK:${PUBLIC_PHYSICAL_NETWORK} \
#    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
#    -v TOOLS_SYSTEM_IP:${TOOLS_SYSTEM_1_IP} \
#    -v TOOLS_SYSTEM_1_IP:${TOOLS_SYSTEM_1_IP} \
#    -v TOOLS_SYSTEM_2_IP:${TOOLS_SYSTEM_2_IP} \
#    -v USER_HOME:${HOME} \
#    -v WORKSPACE:/tmp \
#    ${TESTOPTIONS} ${suite} || true
#done
#rebot exit codes seem to be different
rebot --output ${WORKSPACE}/output.xml --log log_full.html --report None -N openstack output_*.xml || true

echo "Examining the files in data/log and checking file size"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
#collect_logs

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
