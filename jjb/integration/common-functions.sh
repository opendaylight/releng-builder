#!/bin/bash

echo "common-functions.sh is being sourced"

BUNDLEFOLDER=$1

# Basic controller configuration settings
export MAVENCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.url.mvn.cfg
export FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
export CUSTOMPROP=/tmp/${BUNDLEFOLDER}/etc/custom.properties
export LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
export MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
export CONTROLLERMEM="2048m"

# Cluster specific configuration settings
export AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
export MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
export MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf

function print_common_env() {
    cat << EOF
common-functions environment:
MAVENCONF: ${MAVENCONF}
FEATURESCONF: ${FEATURESCONF}
CUSTOMPROP: ${CUSTOMPROP}
LOGCONF: ${LOGCONF}
MEMCONF: ${MEMCONF}
CONTROLLERMEM: ${CONTROLLERMEM}
AKKACONF: ${AKKACONF}
MODULESCONF: ${MODULESCONF}
MODULESHARDSCONF: ${MODULESHARDSCONF}

EOF
}
print_common_env

# Setup JAVA_HOME and MAX_MEM Value in ODL startup config file
function set_java_vars() {
    local -r java_home=$1
    local -r controllermem=$2
    local -r memconf=$3

    echo "Configure\n    java home: ${java_home}\n    max memory: ${controllermem}\n    memconf: ${memconf}"

    sed -ie 's%^# export JAVA_HOME%export JAVA_HOME=${JAVA_HOME:-'"${java_home}"'}%g' ${memconf}
    sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM='"${controllermem}"'/g' ${memconf}
    echo "cat ${memconf}"
    cat ${memconf}

    echo "Set Java version"
    sudo /usr/sbin/alternatives --install /usr/bin/java java ${java_home}/bin/java 1
    sudo /usr/sbin/alternatives --set java ${java_home}/bin/java
    echo "JDK default version ..."
    java -version

    echo "Set JAVA_HOME"
    export JAVA_HOME="${java_home}"

    # shellcheck disable=SC2037
    JAVA_RESOLVED=$(readlink -e "${java_home}/bin/java")
    echo "Java binary pointed at by JAVA_HOME: ${JAVA_RESOLVED}"
} # set_java_vars()

# shellcheck disable=SC2034
# foo appears unused. Verify it or export it.
function configure_karaf_log() {
    local -r karaf_version=$1
    local -r controllerdebugmap=$2
    local logapi=log4j

    # Check what the logging.cfg file is using for the logging api: log4j or log4j2
    grep "log4j2" ${LOGCONF}
    if [ $? -eq 0 ]; then
        logapi=log4j2
    fi

    echo "Configuring the karaf log... karaf_version: ${karaf_version}, logapi: ${logapi}"
    if [ "${logapi}" == "log4j2" ]; then
        # FIXME: Make log size limit configurable from build parameter.
        sed -ie 's/log4j2.appender.rolling.policies.size.size = 16MB/log4j2.appender.rolling.policies.size.size = 1GB/g' ${LOGCONF}
        orgmodule="org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver"
        orgmodule_="${orgmodule//./_}"
        echo "${logapi}.logger.${orgmodule_}.name = WARN" >> ${LOGCONF}
        echo "${logapi}.logger.${orgmodule_}.level = WARN" >> ${LOGCONF}
    else
        sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' ${LOGCONF}
        # FIXME: Make log size limit configurable from build parameter.
        sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=30GB/g' ${LOGCONF}
        echo "${logapi}.logger.org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver = WARN" >> ${LOGCONF}
    fi

    # Add custom logging levels
    # CONTROLLERDEBUGMAP is expected to be a key:value map of space separated values like "module:level module2:level2"
    # where module is abbreviated and does not include "org.opendaylight."
    unset IFS
    echo "controllerdebugmap: ${controllerdebugmap}"
    if [ -n "${controllerdebugmap}" ]; then
        for kv in ${controllerdebugmap}; do
            module="${kv%%:*}"
            level="${kv#*:}"
            echo "module: $module, level: $level"
            # shellcheck disable=SC2157
            if [ -n "${module}" ] && [ -n "${level}" ]; then
                orgmodule="org.opendaylight.${module}"
                if [ "${logapi}" == "log4j2" ]; then
                    orgmodule_="${orgmodule//./_}"
                    echo "${logapi}.logger.${orgmodule_}.name = ${orgmodule}" >> ${LOGCONF}
                    echo "${logapi}.logger.${orgmodule_}.level = ${level}" >> ${LOGCONF}
                else
                    echo "${logapi}.logger.${orgmodule} = ${level}" >> ${LOGCONF}
                fi
            fi
        done
    fi

    echo "cat ${LOGCONF}"
    cat ${LOGCONF}
} # function configure_karaf_log()

function get_os_deploy() {
    local -r num_systems=${1:-$NUM_OPENSTACK_SYSTEM}
    case ${num_systems} in
    1)
        OS_DEPLOY="1cmb-0ctl-0cmp"
        ;;
    2)
        OS_DEPLOY="1cmb-0ctl-1cmp"
        ;;
    3|*)
        OS_DEPLOY="0cmb-1ctl-2cmp"
        ;;
    esac
    export OS_DEPLOY
}

function run_plan() {
    local -r type=$1

    case ${type} in
    script)
        plan=$SCRIPTPLAN
        ;;
    config|*)
        plan=$CONFIGPLAN
        ;;
    esac

    printf "Locating ${type} plan to use...\n"
    plan_filepath="${WORKSPACE}/test/csit/${type}plans/$plan"
    if [ ! -f "${plan_filepath}" ]; then
        plan_filepath="${WORKSPACE}/test/csit/${type}plans/${STREAMTESTPLAN}"
        if [ ! -f "${plan_filepath}" ]; then
            plan_filepath="${WORKSPACE}/test/csit/${type}plans/${TESTPLAN}"
        fi
    fi

    if [ -f "${plan_filepath}" ]; then
        printf "${type} plan exists!!!\n"
        printf "Changing the ${type} plan path...\n"
        cat ${plan_filepath} | sed "s:integration:${WORKSPACE}:" > ${type}plan.txt
        cat ${type}plan.txt
        for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' ${type}plan.txt ); do
            printf "Executing ${line}...\n"
            # shellcheck source=${line} disable=SC1091
            source ${line}
        done
    fi
    printf "Finished running ${type} plans\n"
} # function run_plan()

# Return elapsed time. Usage:
# - Call first time with no arguments and a new timer is returned.
# - Next call with the first argument as the timer and the elapsed time is returned.
function timer()
{
    if [ $# -eq 0 ]; then
        # return the current time
        printf "$(date "+%s")"
    else
        local start_time=$1
        end_time=$(date "+%s")

        if [ -z "$start_time" ]; then
            start_time=$end_time;
        fi

        delta_time=$((end_time - start_time))
        ds=$((delta_time % 60))
        dm=$(((delta_time / 60) % 60))
        dh=$((delta_time / 3600))
        # return the elapsed time
        printf "%d:%02d:%02d" $dh $dm $ds
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
    for enabled_feature in $(csv2ssv ${ENABLE_OS_SERVICES}); do
        if [ "${enabled_feature}" == "${feature}" ]; then
           echo 1
           return
        fi
    done
    echo 0
}

SSH="ssh -t -t"

# shellcheck disable=SC2153
function print_job_parameters() {
    cat << EOF

Job parameters:
DISTROBRANCH: ${DISTROBRANCH}
DISTROSTREAM: ${DISTROSTREAM}
BUNDLE_URL: ${BUNDLE_URL}
CONTROLLERFEATURES: ${CONTROLLERFEATURES}
CONTROLLERDEBUGMAP: ${CONTROLLERDEBUGMAP}
SCRIPTPLAN: ${SCRIPTPLAN}
CONFIGPLAN: ${CONFIGPLAN}
STREAMTESTPLAN: ${STREAMTESTPLAN}
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
ENABLE_ITM_DIRECT_TUNNELS: ${ENABLE_ITM_DIRECT_TUNNELS}
PUBLIC_PHYSICAL_NETWORK: ${PUBLIC_PHYSICAL_NETWORK}
ENABLE_NETWORKING_L2GW: ${ENABLE_NETWORKING_L2GW}
CREATE_INITIAL_NETWORKS: ${CREATE_INITIAL_NETWORKS}
LBAAS_SERVICE_PROVIDER: ${LBAAS_SERVICE_PROVIDER}
NUM_OPENSTACK_SITES: ${NUM_OPENSTACK_SITES}
ODL_SFC_DRIVER: ${ODL_SFC_DRIVER}
ODL_SNAT_MODE: ${ODL_SNAT_MODE}

EOF
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

# List of extra services to extract from journalctl
# Add new services on a separate line, in alpha order, add \ at the end
extra_services_cntl=" \
    dnsmasq.service \
    httpd.service \
    libvirtd.service \
    openvswitch.service \
    ovs-vswitchd.service \
    ovsdb-server.service \
    rabbitmq-server.service \
"

extra_services_cmp=" \
    libvirtd.service \
    openvswitch.service \
    ovs-vswitchd.service \
    ovsdb-server.service \
"

# Collect the logs for the openstack services
# First get all the services started by devstack which would have devstack@ as a prefix
# Next get all the extra services
function collect_openstack_logs() {
    local -r ip=${1}
    local -r folder=${2}
    local -r node_type=${3}
    local oslogs="${folder}/oslogs"

    printf "collect_openstack_logs for ${node_type} node: ${ip} into ${oslogs}\n"
    rm -rf ${oslogs}
    mkdir -p ${oslogs}
    # There are always some logs in /opt/stack/logs and this also covers the
    # pre-queens branches which always use /opt/stack/logs
    rsync -avhe ssh ${ip}:/opt/stack/logs/* ${oslogs} # rsync to prevent copying of symbolic links

    # Starting with queens break out the logs from journalctl
    if [ "${OPENSTACK_BRANCH}" = "stable/queens" ]; then
        cat > ${WORKSPACE}/collect_openstack_logs.sh << EOF
extra_services_cntl="${extra_services_cntl}"
extra_services_cmp="${extra_services_cmp}"

function extract_from_journal() {
    local -r services=\${1}
    local -r folder=\${2}
    local -r node_type=\${3}
    printf "extract_from_journal folder: \${folder}, services: \${services}\n"
    for service in \${services}; do
        # strip anything before @ and anything after .
        # devstack@g-api.service will end as g-api
        service_="\${service#*@}"
        service_="\${service_%.*}"
        sudo journalctl -u "\${service}" > "\${folder}/\${service_}.log"
    done
}

rm -rf /tmp/oslogs
mkdir -p /tmp/oslogs
systemctl list-unit-files --all > /tmp/oslogs/systemctl.units.log 2>&1
svcs=\$(grep devstack@ /tmp/oslogs/systemctl.units.log | awk '{print \$1}')
extract_from_journal "\${svcs}" "/tmp/oslogs"
if [ "\${node_type}" = "control" ]; then
    extract_from_journal "\${extra_services_cntl}" "/tmp/oslogs"
else
    extract_from_journal "\${extra_services_cmp}" "/tmp/oslogs"
fi
ls -al /tmp/oslogs
EOF
# cat > ${WORKSPACE}/collect_openstack_logs.sh << EOF
        printf "collect_openstack_logs for ${node_type} node: ${ip} into ${oslogs}, executing script\n"
        cat ${WORKSPACE}/collect_openstack_logs.sh
        scp ${WORKSPACE}/collect_openstack_logs.sh ${ip}:/tmp
        ${SSH} ${ip} "bash /tmp/collect_openstack_logs.sh > /tmp/collect_openstack_logs.log 2>&1"
        rsync -avhe ssh ${ip}:/tmp/oslogs/* ${oslogs}
        scp ${ip}:/tmp/collect_openstack_logs.log ${oslogs}
    fi # if [ "${OPENSTACK_BRANCH}" = "stable/queens" ]; then
}

function collect_netvirt_logs() {
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
        ssh ${!CONTROLLERIP} "${JAVA_HOME}/bin/jstack -l ${pid}" > ${WORKSPACE}/karaf_${i}_${pid}_threads_after.log || true
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
        mv /tmp/odl${i}_exceptions.txt ${NODE_FOLDER}
        rm ${NODE_FOLDER}/odl${i}_karaf.log.tar
        mv *_threads* ${NODE_FOLDER}
        mv ps_* ${NODE_FOLDER}
        mv ${NODE_FOLDER} ${WORKSPACE}/archives/
    done

    print_job_parameters > ${WORKSPACE}/archives/params.txt

    # Control Node
    for i in `seq 1 ${NUM_OPENSTACK_CONTROL_NODES}`; do
        OSIP=OPENSTACK_CONTROL_NODE_${i}_IP
        if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
            echo "collect_logs: for openstack combo node ip: ${!OSIP}"
            NODE_FOLDER="combo_${i}"
        else
            echo "collect_logs: for openstack control node ip: ${!OSIP}"
            NODE_FOLDER="control_${i}"
        fi
        mkdir -p ${NODE_FOLDER}
        scp extra_debug.sh ${!OSIP}:/tmp
        # Capture compute logs if this is a combo node
        if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
            scp ${!OSIP}:/etc/nova/nova.conf ${NODE_FOLDER}
            scp ${!OSIP}:/etc/nova/nova-cpu.conf ${NODE_FOLDER}
            scp ${!OSIP}:/etc/openstack/clouds.yaml ${NODE_FOLDER}
            rsync --rsync-path="sudo rsync" -avhe ssh ${!OSIP}:/var/log/nova-agent.log ${NODE_FOLDER}
        fi
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
        collect_openstack_logs "${!OSIP}" "${NODE_FOLDER}" "control"
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
        collect_openstack_logs "${!OSIP}" "${NODE_FOLDER}" "compute"
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
    else
        echo "tempest results not found in ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/0"
    fi
} # collect_netvirt_logs()
