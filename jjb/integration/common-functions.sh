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
ACTUALFEATURES: ${ACTUALFEATURES}
FEATURESCONF: ${FEATURESCONF}
CUSTOMPROP: ${CUSTOMPROP}
LOGCONF: ${LOGCONF}
MEMCONF: ${MEMCONF}
CONTROLLERMEM: ${CONTROLLERMEM}
AKKACONF: ${AKKACONF}
MODULESCONF: ${MODULESCONF}
MODULESHARDSCONF: ${MODULESHARDSCONF}
SUITES: ${SUITES}

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
        # From Neon the default karaf file size is 64 MB
        sed -ie 's/log4j2.appender.rolling.policies.size.size = 64MB/log4j2.appender.rolling.policies.size.size = 1GB/g' ${LOGCONF}
        # Flourine still uses 16 MB
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
    # CONTROLLERDEBUGMAP is expected to be a key:value map of space separated
    # values like "module:level module2:level2" where module is abbreviated and
    # does not include "org.opendaylight."
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

function configure_karaf_log_for_apex() {
    # TODO: add the extra steps to this function to do any extra work
    # in this apex environment like we do in our standard environment.
    # EX: log size, rollover, etc.

    # Modify ODL Log Levels, if needed, for new distribution. This will modify
    # the control nodes hiera data which will be used during the puppet deploy
    # CONTROLLERDEBUGMAP is expected to be a key:value map of space separated
    # values like "module:level module2:level2" where module is abbreviated and
    # does not include "org.opendaylight."

    local -r controller_ip=$1

    unset IFS
    # shellcheck disable=SC2153
    echo "CONTROLLERDEBUGMAP: ${CONTROLLERDEBUGMAP}"
    if [ -n "${CONTROLLERDEBUGMAP}" ]; then
        logging_config='\"opendaylight::log_levels\": {'
        for kv in ${CONTROLLERDEBUGMAP}; do
            module="${kv%%:*}"
            level="${kv#*:}"
            echo "module: $module, level: $level"
            # shellcheck disable=SC2157
            if [ -n "${module}" ] && [ -n "${level}" ]; then
                orgmodule="org.opendaylight.${module}"
                logging_config="${logging_config} \\\"${orgmodule}\\\": \\\"${level}\\\","
            fi
        done
        # replace the trailing comma with a closing brace followed by trailing comma
        logging_config=${logging_config%,}" },"
        echo $logging_config

        # fine a sane line number to inject the custom logging json
        lineno=$(ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo grep -Fn 'opendaylight::log_mechanism' /etc/puppet/hieradata/service_configs.json" | awk -F: '{print $1}')
        ssh $controller_ip "sudo sed -i \"${lineno}i ${logging_config}\" /etc/puppet/hieradata/service_configs.json"
        ssh $controller_ip "sudo cat /etc/puppet/hieradata/service_configs.json"
    fi
} # function configure_karaf_log_for_apex()

function configure_odl_features_for_apex() {

    # if the environment variable $ACTUALFEATURES is not null, then rewrite
    # the puppet config file with the features given in that variable, otherwise
    # this function is a noop

    local -r controller_ip=$1
    local -r config_file=/etc/puppet/hieradata/service_configs.json

cat > /tmp/set_odl_features.sh << EOF
sudo jq '.["opendaylight::extra_features"] |= []' $config_file > tmp.json && mv tmp.json $config_file
for feature in $(echo $ACTUALFEATURES | sed "s/,/ /g"); do
    sudo jq --arg jq_arg \$feature '.["opendaylight::extra_features"] |= . + [\$jq_arg]' $config_file > tmp && mv tmp $config_file;
done
echo "Modified puppet-opendaylight service_configs.json..."
cat $config_file
EOF

    echo "Feature configuration script..."
    cat /tmp/set_odl_features.sh

    if [ -n "${ACTUALFEATURES}" ]; then
        scp /tmp/set_odl_features.sh $controller_ip:/tmp/set_odl_features.sh
        ssh $controller_ip "sudo bash /tmp/set_odl_features.sh"
    fi

} # function configure_odl_features_for_apex()

function get_os_deploy() {
    local -r num_systems=${1:-$NUM_OPENSTACK_SYSTEM}
    case ${num_systems} in
    1)
        OPENSTACK_TOPO="1cmb-0ctl-0cmp"
        ;;
    2)
        OPENSTACK_TOPO="1cmb-0ctl-1cmp"
        ;;
    3|*)
        OPENSTACK_TOPO="0cmb-1ctl-2cmp"
        ;;
    esac
    export OPENSTACK_TOPO
}

function get_test_suites() {

    #let the caller pick the name of the variable we will assign the suites to
    local __suite_list=$1

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
        suite_list=$(egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ')
    else
        suite_list=""
        workpath="${WORKSPACE}/test/csit/suites"
        for suite in ${SUITES}; do
            fullsuite="${workpath}/${suite}"
            if [ -z "${suite_list}" ]; then
                suite_list+=${fullsuite}
            else
                suite_list+=" "${fullsuite}
            fi
        done
    fi

    eval $__suite_list="'$suite_list'"
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

    printf "Locating %s plan to use...\n" "${type}"
    plan_filepath="${WORKSPACE}/test/csit/${type}plans/$plan"
    if [ ! -f "${plan_filepath}" ]; then
        plan_filepath="${WORKSPACE}/test/csit/${type}plans/${STREAMTESTPLAN}"
        if [ ! -f "${plan_filepath}" ]; then
            plan_filepath="${WORKSPACE}/test/csit/${type}plans/${TESTPLAN}"
        fi
    fi

    if [ -f "${plan_filepath}" ]; then
        printf "%s plan exists!!!\n" "${type}"
        printf "Changing the %s plan path...\n" "${type}"
        cat ${plan_filepath} | sed "s:integration:${WORKSPACE}:" > ${type}plan.txt
        cat ${type}plan.txt
        for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' ${type}plan.txt ); do
            printf "Executing %s...\n" "${line}"
            # shellcheck source=${line} disable=SC1091
            source ${line}
        done
    fi
    printf "Finished running %s plans\n" "${type}"
} # function run_plan()

# Return elapsed time. Usage:
# - Call first time with no arguments and a new timer is returned.
# - Next call with the first argument as the timer and the elapsed time is returned.
function timer()
{
    if [ $# -eq 0 ]; then
        # return the current time
        printf "%s" "$(date "+%s")"
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
        ssv=$(echo "${csv}" | sed 's/,/ /g' | sed 's/\ \ */\ /g')
    fi

    echo "${ssv}"
} # csv2ssv

function is_openstack_feature_enabled() {
    local feature=$1
    for enabled_feature in $(csv2ssv "${ENABLE_OS_SERVICES}"); do
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
ODL_SFC_DRIVER: ${ODL_SFC_DRIVER}
ODL_SNAT_MODE: ${ODL_SNAT_MODE}

EOF
}

function tcpdump_start() {
    local -r prefix=$1
    local -r ip=$2
    local -r filter=$3
    filter_=${filter// /_}

    printf "node %s, %s_%s__%s: starting tcpdump\n" "${ip}" "${prefix}" "${ip}" "${filter}"
    # $fileter needs to be parsed client-side
    # shellcheck disable=SC2029
    ssh "${ip}" "nohup sudo /usr/sbin/tcpdump -vvv -ni eth0 ${filter} -w /tmp/tcpdump_${prefix}_${ip}__${filter_}.pcap > /tmp/tcpdump_start.log 2>&1 &"
    ${SSH} "${ip}" "ps -ef | grep tcpdump"
}

function tcpdump_stop() {
    local -r ip=$1

    printf "node %s: stopping tcpdump\n" "$ip"
    ${SSH} "${ip}" "ps -ef | grep tcpdump.sh"
    ${SSH} "${ip}" "sudo pkill -f tcpdump"
    ${SSH} "${ip}" "sudo xz -9ekvvf /tmp/*.pcap"
    ${SSH} "${ip}" "sudo ls -al /tmp/*.pcap"
    # copy_logs will copy any *.xz files
}

# Collect the list of files on the hosts
function collect_files() {
    local -r ip=$1
    local -r folder=$2
    finddir=/tmp/finder
    ${SSH} "${ip}" "mkdir -p ${finddir}"
    ${SSH} "${ip}" "sudo find /etc > ${finddir}/find.etc.txt"
    ${SSH} "${ip}" "sudo find /opt/stack > ${finddir}/find.opt.stack.txt"
    ${SSH} "${ip}" "sudo find /var > ${finddir}/find2.txt"
    ${SSH} "${ip}" "sudo find /var > ${finddir}/find.var.txt"
    ${SSH} "${ip}" "sudo tar -cf - -C /tmp finder | xz -T 0 > /tmp/find.tar.xz"
    scp "${ip}":/tmp/find.tar.xz "${folder}"
    mkdir -p "${finddir}"
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh "${ip}":/etc/ > "${finddir}"/rsync.etc.txt
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh "${ip}":/opt/stack/ > "${finddir}"/rsync.opt.stack.txt
    rsync --rsync-path="sudo rsync" --list-only -arvhe ssh "${ip}":/var/ > "${finddir}"/rsync.var.txt
    tar -cf - -C /tmp finder | xz -T 0 > /tmp/rsync.tar.xz
    cp /tmp/rsync.tar.xz "${folder}"
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

    printf "collect_openstack_logs for %s node: %s into %s\n" "${node_type}" "${ip}" "${oslogs}"
    rm -rf "${oslogs}"
    mkdir -p "${oslogs}"
    # There are always some logs in /opt/stack/logs and this also covers the
    # pre-queens branches which always use /opt/stack/logs
    rsync -avhe ssh "${ip}":/opt/stack/logs/* "${oslogs}" # rsync to prevent copying of symbolic links

    # Starting with queens break out the logs from journalctl
    if [ "${OPENSTACK_BRANCH}" = "stable/queens" ]; then
        cat > "${WORKSPACE}"/collect_openstack_logs.sh << EOF
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
        printf "collect_openstack_logs for %s node: %s into %s, executing script\n" "${node_type}" "${ip}" "${oslogs}"
        cat "${WORKSPACE}"/collect_openstack_logs.sh
        scp "${WORKSPACE}"/collect_openstack_logs.sh "${ip}":/tmp
        ${SSH} "${ip}" "bash /tmp/collect_openstack_logs.sh > /tmp/collect_openstack_logs.log 2>&1"
        rsync -avhe ssh "${ip}":/tmp/oslogs/* "${oslogs}"
        scp "${ip}":/tmp/collect_openstack_logs.log "${oslogs}"
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
    mkdir -p "${WORKSPACE}"/archives

    mv /tmp/changes.txt "${WORKSPACE}"/archives
    mv /tmp/validations.txt "${WORKSPACE}"/archives
    mv "${WORKSPACE}"/rabbit.txt "${WORKSPACE}"/archives
    mv "${WORKSPACE}"/haproxy.cfg "${WORKSPACE}"/archives
    ssh "${OPENSTACK_HAPROXY_1_IP}" "sudo journalctl -u haproxy > /tmp/haproxy.log"
    scp "${OPENSTACK_HAPROXY_1_IP}":/tmp/haproxy.log "${WORKSPACE}"/archives/

    sleep 5
    # FIXME: Do not create .tar and gzip before copying.
    for i in $(seq 1 "${NUM_ODL_SYSTEM}"); do
        CONTROLLERIP=ODL_SYSTEM_${i}_IP
        echo "collect_logs: for opendaylight controller ip: ${!CONTROLLERIP}"
        NODE_FOLDER="odl_${i}"
        mkdir -p "${NODE_FOLDER}"
        echo "Lets's take the karaf thread dump again..."
        ssh "${!CONTROLLERIP}" "sudo ps aux" > "${WORKSPACE}"/ps_after.log
        pid=$(grep org.apache.karaf.main.Main "${WORKSPACE}"/ps_after.log | grep -v grep | tr -s ' ' | cut -f2 -d' ')
        echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
        # $pid needs to be parsed client-side
        # shellcheck disable=SC2029
        ssh "${!CONTROLLERIP}" "${JAVA_HOME}/bin/jstack -l ${pid}" > "${WORKSPACE}/karaf_${i}_${pid}_threads_after.log" || true
        echo "killing karaf process..."
        # shellcheck disable=SC2016
        ${SSH} "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
        ${SSH} "${!CONTROLLERIP}" "sudo journalctl > /tmp/journalctl.log"
        scp "${!CONTROLLERIP}":/tmp/journalctl.log "${NODE_FOLDER}"
        ${SSH} "${!CONTROLLERIP}" "dmesg -T > /tmp/dmesg.log"
        scp "${!CONTROLLERIP}":/tmp/dmesg.log "${NODE_FOLDER}"
        ${SSH} "${!CONTROLLERIP}" "tar -cf - -C /tmp/${BUNDLEFOLDER} etc | xz -T 0 > /tmp/etc.tar.xz"
        scp "${!CONTROLLERIP}":/tmp/etc.tar.xz "${NODE_FOLDER}"
        ${SSH} "${!CONTROLLERIP}" "cp -r /tmp/${BUNDLEFOLDER}/data/log /tmp/odl_log"
        ${SSH} "${!CONTROLLERIP}" "tar -cf /tmp/odl${i}_karaf.log.tar /tmp/odl_log/*"
        scp "${!CONTROLLERIP}:/tmp/odl${i}_karaf.log.tar" "${NODE_FOLDER}"
        ${SSH} "${!CONTROLLERIP}" "tar -cf /tmp/odl${i}_zrpcd.log.tar /tmp/zrpcd.init.log"
        scp "${!CONTROLLERIP}:/tmp/odl${i}_zrpcd.log.tar" "${NODE_FOLDER}"
        tar -xvf "${NODE_FOLDER}/odl${i}_karaf.log.tar" -C "${NODE_FOLDER}" --strip-components 2 --transform "s/karaf/odl${i}_karaf/g"
        grep "ROBOT MESSAGE\| ERROR " "${NODE_FOLDER}/odl${i}_karaf.log" > "${NODE_FOLDER}/odl${i}_err.log"
        grep "ROBOT MESSAGE\| ERROR \| WARN \|Exception" \
            "${NODE_FOLDER}/odl${i}_karaf.log" > "${NODE_FOLDER}/odl${i}_err_warn_exception.log"
        # Print ROBOT lines and print Exception lines. For exception lines also print the previous line for context
        sed -n -e '/ROBOT MESSAGE/P' -e '$!N;/Exception/P;D' "${NODE_FOLDER}/odl${i}_karaf.log" > "${NODE_FOLDER}/odl${i}_exception.log"
        mv "/tmp/odl${i}_exceptions.txt" "${NODE_FOLDER}"
        rm "${NODE_FOLDER}/odl${i}_karaf.log.tar"
        mv -- *_threads* "${NODE_FOLDER}"
        mv ps_* "${NODE_FOLDER}"
        mv "${NODE_FOLDER}" "${WORKSPACE}"/archives/
    done

    print_job_parameters > "${WORKSPACE}"/archives/params.txt

    # Control Node
    for i in $(seq 1 "${NUM_OPENSTACK_CONTROL_NODES}"); do
        OSIP=OPENSTACK_CONTROL_NODE_${i}_IP
        if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
            echo "collect_logs: for openstack combo node ip: ${!OSIP}"
            NODE_FOLDER="combo_${i}"
        else
            echo "collect_logs: for openstack control node ip: ${!OSIP}"
            NODE_FOLDER="control_${i}"
        fi
        mkdir -p "${NODE_FOLDER}"
        tcpdump_stop "${!OSIP}"
        scp extra_debug.sh "${!OSIP}":/tmp
        # Capture compute logs if this is a combo node
        if [ "$(is_openstack_feature_enabled n-cpu)" == "1" ]; then
            scp "${!OSIP}":/etc/nova/nova.conf "${NODE_FOLDER}"
            scp "${!OSIP}":/etc/nova/nova-cpu.conf "${NODE_FOLDER}"
            scp "${!OSIP}":/etc/openstack/clouds.yaml "${NODE_FOLDER}"
            rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/nova-agent.log "${NODE_FOLDER}"
        fi
        ${SSH} "${!OSIP}" "bash /tmp/extra_debug.sh > /tmp/extra_debug.log 2>&1"
        scp "${!OSIP}":/etc/dnsmasq.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/keystone/keystone.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/keystone/keystone-uwsgi-admin.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/keystone/keystone-uwsgi-public.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/kuryr/kuryr.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/dhcp_agent.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/metadata_agent.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/neutron.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/neutron_lbaas.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/plugins/ml2/ml2_conf.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/neutron/services/loadbalancer/haproxy/lbaas_agent.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/nova.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/nova-api-uwsgi.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/nova_cell1.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/nova-cpu.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/placement-uwsgi.ini "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/openstack/clouds.yaml "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/devstack/.stackenv "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/devstack/nohup.out "${NODE_FOLDER}"/stack.log
        scp "${!OSIP}":/opt/stack/devstack/openrc "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/requirements/upper-constraints.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/tempest/etc/tempest.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/*.xz "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/dmesg.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/extra_debug.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/get_devstack.sh.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/install_ovs.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/journalctl.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/ovsdb-tool.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/tcpdump_start.log "${NODE_FOLDER}"
        collect_files "${!OSIP}" "${NODE_FOLDER}"
        ${SSH} "${!OSIP}" "sudo tar -cf - -C /var/log rabbitmq | xz -T 0 > /tmp/rabbitmq.tar.xz "
        scp "${!OSIP}":/tmp/rabbitmq.tar.xz "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/etc/hosts "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/usr/lib/systemd/system/haproxy.service "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/audit/audit.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/httpd/keystone_access.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/httpd/keystone.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/messages* "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/openvswitch/ovs-vswitchd.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/openvswitch/ovsdb-server.log "${NODE_FOLDER}"
        collect_openstack_logs "${!OSIP}" "${NODE_FOLDER}" "control"
        mv "local.conf_control_${!OSIP}" "${NODE_FOLDER}/local.conf"
        # qdhcp files are created by robot tests and copied into /tmp/qdhcp during the test
        tar -cf - -C /tmp qdhcp | xz -T 0 > /tmp/qdhcp.tar.xz
        mv /tmp/qdhcp.tar.xz "${NODE_FOLDER}"
        mv "${NODE_FOLDER}" "${WORKSPACE}"/archives/
    done

    # Compute Nodes
    for i in $(seq 1 "${NUM_OPENSTACK_COMPUTE_NODES}"); do
        OSIP="OPENSTACK_COMPUTE_NODE_${i}_IP"
        echo "collect_logs: for openstack compute node ip: ${!OSIP}"
        NODE_FOLDER="compute_${i}"
        mkdir -p "${NODE_FOLDER}"
        tcpdump_stop "${!OSIP}"
        scp extra_debug.sh "${!OSIP}":/tmp
        ${SSH} "${!OSIP}" "bash /tmp/extra_debug.sh > /tmp/extra_debug.log 2>&1"
        scp "${!OSIP}":/etc/nova/nova.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/nova/nova-cpu.conf "${NODE_FOLDER}"
        scp "${!OSIP}":/etc/openstack/clouds.yaml "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/devstack/.stackenv "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/devstack/nohup.out "${NODE_FOLDER}"/stack.log
        scp "${!OSIP}":/opt/stack/devstack/openrc "${NODE_FOLDER}"
        scp "${!OSIP}":/opt/stack/requirements/upper-constraints.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/*.xz "${NODE_FOLDER}"/
        scp "${!OSIP}":/tmp/dmesg.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/extra_debug.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/get_devstack.sh.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/install_ovs.txt "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/journalctl.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/ovsdb-tool.log "${NODE_FOLDER}"
        scp "${!OSIP}":/tmp/tcpdump_start.log "${NODE_FOLDER}"
        collect_files "${!OSIP}" "${NODE_FOLDER}"
        ${SSH} "${!OSIP}" "sudo tar -cf - -C /var/log libvirt | xz -T 0 > /tmp/libvirt.tar.xz "
        scp "${!OSIP}":/tmp/libvirt.tar.xz "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/etc/hosts "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/audit/audit.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/messages* "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/nova-agent.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/openvswitch/ovs-vswitchd.log "${NODE_FOLDER}"
        rsync --rsync-path="sudo rsync" -avhe ssh "${!OSIP}":/var/log/openvswitch/ovsdb-server.log "${NODE_FOLDER}"
        collect_openstack_logs "${!OSIP}" "${NODE_FOLDER}" "compute"
        mv "local.conf_compute_${!OSIP}" "${NODE_FOLDER}"/local.conf
        mv "${NODE_FOLDER}" "${WORKSPACE}"/archives/
    done

    # Tempest
    DEVSTACK_TEMPEST_DIR="/opt/stack/tempest"
    TESTREPO=".stestr"
    TEMPEST_LOGS_DIR="${WORKSPACE}/archives/tempest"
    # Look for tempest test results in the $TESTREPO dir and copy if found
    if ${SSH} "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo sh -c '[ -f ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/0 ]'"; then
        ${SSH} "${OPENSTACK_CONTROL_NODE_1_IP}" "for I in \$(sudo ls ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/ | grep -E '^[0-9]+$'); do sudo sh -c \"${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/subunit-1to2 < ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/\${I} >> ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt\"; done"
        ${SSH} "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo sh -c '${DEVSTACK_TEMPEST_DIR}/.tox/tempest/bin/python ${DEVSTACK_TEMPEST_DIR}/.tox/tempest/lib/python2.7/site-packages/os_testr/subunit2html.py ${DEVSTACK_TEMPEST_DIR}/subunit_log.txt ${DEVSTACK_TEMPEST_DIR}/tempest_results.html'"
        mkdir -p "${TEMPEST_LOGS_DIR}"
        scp "${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest_results.html" "${TEMPEST_LOGS_DIR}"
        scp "${OPENSTACK_CONTROL_NODE_1_IP}:${DEVSTACK_TEMPEST_DIR}/tempest.log" "${TEMPEST_LOGS_DIR}"
    else
        echo "tempest results not found in ${DEVSTACK_TEMPEST_DIR}/${TESTREPO}/0"
    fi
} # collect_netvirt_logs()

# Utility function for joining strings.
function join() {
    delim=' '
    final=$1; shift

    for str in "$@" ; do
        final=${final}${delim}${str}
    done

    echo "${final}"
}

function get_nodes_list() {
    # Create the string for nodes
    for i in $(seq 1 "${NUM_ODL_SYSTEM}") ; do
        CONTROLLERIP=ODL_SYSTEM_${i}_IP
        nodes[$i]=${!CONTROLLERIP}
    done

    nodes_list=$(join "${nodes[@]}")
    echo "${nodes_list}"
}

function get_features() {
    if [ "${CONTROLLERSCOPE}" == 'all' ]; then
        ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
        export CONTROLLERMEM="3072m"
    else
        ACTUALFEATURES="odl-infrautils-ready,${CONTROLLERFEATURES}"
    fi

    # Some versions of jenkins job builder result in feature list containing spaces
    # and ending in newline. Remove all that.
    ACTUALFEATURES=$(echo "${ACTUALFEATURES}" | tr -d '\n \r')
    echo "ACTUALFEATURES: ${ACTUALFEATURES}"

    # In the case that we want to install features via karaf shell, a space separated list of
    # ACTUALFEATURES IS NEEDED
    SPACE_SEPARATED_FEATURES=$(echo "${ACTUALFEATURES}" | tr ',' ' ')
    echo "SPACE_SEPARATED_FEATURES: ${SPACE_SEPARATED_FEATURES}"

    export ACTUALFEATURES
    export SPACE_SEPARATED_FEATURES
}

# Create the configuration script to be run on controllers.
function create_configuration_script() {
    cat > "${WORKSPACE}"/configuration-script.sh <<EOF
set -x
source /tmp/common-functions.sh ${BUNDLEFOLDER}

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution from ${ACTUAL_BUNDLE_URL}"
wget --progress=dot:mega '${ACTUAL_BUNDLE_URL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Adding external repositories..."
sed -ie "s%org.ops4j.pax.url.mvn.repositories=%org.ops4j.pax.url.mvn.repositories=https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot@id=opendaylight-snapshot@snapshots, https://nexus.opendaylight.org/content/repositories/public@id=opendaylight-mirror, http://repo1.maven.org/maven2@id=central, http://repository.springsource.com/maven/bundles/release@id=spring.ebr.release, http://repository.springsource.com/maven/bundles/external@id=spring.ebr.external, http://zodiac.springsource.com/maven/bundles/release@id=gemini, http://repository.apache.org/content/groups/snapshots-group@id=apache@snapshots@noreleases, https://oss.sonatype.org/content/repositories/snapshots@id=sonatype.snapshots.deploy@snapshots@noreleases, https://oss.sonatype.org/content/repositories/ops4j-snapshots@id=ops4j.sonatype.snapshots.deploy@snapshots@noreleases%g" ${MAVENCONF}
cat ${MAVENCONF}

if [[ "$USEFEATURESBOOT" == "True" ]]; then
    echo "Configuring the startup features..."
    sed -ie "s/\(featuresBoot=\|featuresBoot =\)/featuresBoot = ${ACTUALFEATURES},/g" ${FEATURESCONF}
fi

FEATURE_TEST_STRING="features-integration-test"
KARAF_VERSION=${KARAF_VERSION:-karaf4}
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    FEATURE_TEST_STRING="features-test"
fi

sed -ie "s%\(featuresRepositories=\|featuresRepositories =\)%featuresRepositories = mvn:org.opendaylight.integration/\${FEATURE_TEST_STRING}/${BUNDLE_VERSION}/xml/features,mvn:org.apache.karaf.decanter/apache-karaf-decanter/1.0.0/xml/features,%g" ${FEATURESCONF}
if [[ ! -z "${REPO_URL}" ]]; then
   sed -ie "s%featuresRepositories =%featuresRepositories = ${REPO_URL},%g" ${FEATURESCONF}
fi
cat ${FEATURESCONF}

configure_karaf_log "${KARAF_VERSION}" "${CONTROLLERDEBUGMAP}"

set_java_vars "${JAVA_HOME}" "${CONTROLLERMEM}" "${MEMCONF}"

echo "Listing all open ports on controller system..."
netstat -pnatu

# Copy shard file if exists
if [ -f /tmp/custom_shard_config.txt ]; then
    echo "Custom shard config exists!!!"
    echo "Copying the shard config..."
    cp /tmp/custom_shard_config.txt /tmp/${BUNDLEFOLDER}/bin/
fi

echo "Configuring cluster"
/tmp/${BUNDLEFOLDER}/bin/configure_cluster.sh \$1 ${nodes_list}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}
EOF
# cat > ${WORKSPACE}/configuration-script.sh <<EOF
}

# Create the startup script to be run on controllers.
function create_startup_script() {
    cat > "${WORKSPACE}"/startup-script.sh <<EOF
echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p /tmp/${BUNDLEFOLDER}/data/log

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start
EOF
# cat > ${WORKSPACE}/startup-script.sh <<EOF
}

function create_post_startup_script() {
    cat > "${WORKSPACE}"/post-startup-script.sh <<EOF
if [[ "$USEFEATURESBOOT" != "True" ]]; then

    # wait up to 60s for karaf port 8101 to be opened, polling every 5s
    loop_count=0;
    until [[ \$loop_count -ge 12 ]]; do
        netstat -na | grep 8101 && break;
        loop_count=\$[\$loop_count+1];
        sleep 5;
    done

    echo "going to feature:install --no-auto-refresh ${SPACE_SEPARATED_FEATURES} one at a time"
    for feature in ${SPACE_SEPARATED_FEATURES}; do
        sshpass -p karaf ssh -o StrictHostKeyChecking=no \
                             -o UserKnownHostsFile=/dev/null \
                             -o LogLevel=error \
                             -p 8101 karaf@localhost \
                             feature:install --no-auto-refresh \$feature;
    done

    echo "ssh to karaf console to list -i installed features"
    sshpass -p karaf ssh -o StrictHostKeyChecking=no \
                         -o UserKnownHostsFile=/dev/null \
                         -o LogLevel=error \
                         -p 8101 karaf@localhost \
                         feature:list -i
fi

echo "Waiting up to 3 minutes for controller to come up, checking every 5 seconds..."
for i in {1..36}; do
    sleep 5;
    grep 'org.opendaylight.infrautils.*System ready' /tmp/${BUNDLEFOLDER}/data/log/karaf.log
    if [ \$? -eq 0 ]; then
        echo "Controller is UP"
        break
    fi
done;

# if we ended up not finding ready status in the above loop, we can output some debugs
grep 'org.opendaylight.infrautils.*System ready' /tmp/${BUNDLEFOLDER}/data/log/karaf.log
if [ $? -ne 0 ]; then
    echo "Timeout Controller DOWN"
    echo "Dumping first 500K bytes of karaf log..."
    head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
    echo "Dumping last 500K bytes of karaf log..."
    tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
    echo "Listing all open ports on controller system"
    netstat -pnatu
    exit 1
fi

echo "Listing all open ports on controller system..."
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"\$1\" in log file"
    if grep --quiet "\$1" "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"; then
        echo ABORTING: found "\$1"
        echo "Dumping first 500K bytes of karaf log..."
        head --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Dumping last 500K bytes of karaf log..."
        tail --bytes=500K "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
        exit 1
    fi
}

exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'
EOF
# cat > ${WORKSPACE}/post-startup-script.sh <<EOF
}

# Copy over the configuration script and configuration files to each controller
# Execute the configuration script on each controller.
function copy_and_run_configuration_script() {
    for i in $(seq 1 "${NUM_ODL_SYSTEM}"); do
        CONTROLLERIP="ODL_SYSTEM_${i}_IP"
        echo "Configuring member-${i} with IP address ${!CONTROLLERIP}"
        scp "${WORKSPACE}"/configuration-script.sh "${!CONTROLLERIP}":/tmp/
        # $i needs to be parsed client-side
        # shellcheck disable=SC2029
        ssh "${!CONTROLLERIP}" "bash /tmp/configuration-script.sh ${i}"
    done
}

# Copy over the startup script to each controller and execute it.
function copy_and_run_startup_script() {
    for i in $(seq 1 "${NUM_ODL_SYSTEM}"); do
        CONTROLLERIP="ODL_SYSTEM_${i}_IP"
        echo "Starting member-${i} with IP address ${!CONTROLLERIP}"
        scp "${WORKSPACE}"/startup-script.sh "${!CONTROLLERIP}":/tmp/
        ssh "${!CONTROLLERIP}" "bash /tmp/startup-script.sh"
    done
}

function copy_and_run_post_startup_script() {
    seed_index=1
    for i in $(seq 1 "${NUM_ODL_SYSTEM}"); do
        CONTROLLERIP="ODL_SYSTEM_${i}_IP"
        echo "Execute the post startup script on controller ${!CONTROLLERIP}"
        scp "${WORKSPACE}"/post-startup-script.sh "${!CONTROLLERIP}":/
        # $seed_index needs to be parsed client-side
        # shellcheck disable=SC2029
        ssh "${!CONTROLLERIP}" "bash /tmp/post-startup-script.sh $(( seed_index++ ))"
        if [ $(( i % NUM_ODL_SYSTEM )) == 0 ]; then
            seed_index=1
        fi
    done
}

function create_controller_variables() {
    echo "Generating controller variables..."
    for i in $(seq 1 "${NUM_ODL_SYSTEM}"); do
        CONTROLLERIP="ODL_SYSTEM_${i}_IP"
        odl_variables=${odl_variables}" -v ${CONTROLLERIP}:${!CONTROLLERIP}"
        echo "Lets's take the karaf thread dump"
        ssh "${!CONTROLLERIP}" "sudo ps aux" > "${WORKSPACE}"/ps_before.log
        pid=$(grep org.apache.karaf.main.Main "${WORKSPACE}"/ps_before.log | grep -v grep | tr -s ' ' | cut -f2 -d' ')
        echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
        # $i needs to be parsed client-side
        # shellcheck disable=SC2029
        ssh "${!CONTROLLERIP}" "${JAVA_HOME}/bin/jstack -l ${pid}" > "${WORKSPACE}/karaf_${i}_${pid}_threads_before.log" || true
    done
}

# Function to build OVS from git repo
function build_ovs() {
    local -r ip=$1
    local -r version=$2
    local -r rpm_path="$3"

    echo "Building OVS ${version} on ${ip} ..."
    cat > "${WORKSPACE}"/build_ovs.sh << EOF
set -ex -o pipefail

echo '---> Building openvswitch version ${version}'

# Install running kernel devel packages
K_VERSION=\$(uname -r)
YUM_OPTS="-y --disablerepo=* --enablerepo=base,updates,extra,C*-base,C*-updates,C*-extras"
# Install centos-release to update vault repos from which to fetch
# kernel devel packages
sudo yum \${YUM_OPTS} install centos-release yum-utils @'Development Tools' rpm-build
sudo yum \${YUM_OPTS} install kernel-{devel,headers}-\${K_VERSION}

TMP=\$(mktemp -d)
pushd \${TMP}

git clone https://github.com/openvswitch/ovs.git
cd ovs

if [ "${version}" = "v2.6.1-nsh" ]; then
    git checkout v2.6.1
    echo "Will apply nsh patches for OVS version 2.6.1"
    git clone https://github.com/yyang13/ovs_nsh_patches.git ../ovs_nsh_patches
    git apply ../ovs_nsh_patches/v2.6.1_centos7/*.patch
else
    git checkout ${version}
fi

# On early versions of OVS, flake warnings would fail the build.
# Remove it.
sudo pip uninstall -y flake8

# Get rid of sphinx dep as it conflicts with the already
# installed one (via pip). Docs wont be built.
sed -i "/BuildRequires:.*sphinx.*/d" rhel/openvswitch-fedora.spec.in

sed -e 's/@VERSION@/0.0.1/' rhel/openvswitch-fedora.spec.in > /tmp/ovs.spec
sed -e 's/@VERSION@/0.0.1/' rhel/openvswitch-kmod-fedora.spec.in > /tmp/ovs-kmod.spec
sed -e 's/@VERSION@/0.0.1/' rhel/openvswitch-dkms.spec.in > /tmp/ovs-dkms.spec
sudo yum-builddep \${YUM_OPTS} /tmp/ovs.spec /tmp/ovs-kmod.spec /tmp/ovs-dkms.spec
rm /tmp/ovs.spec /tmp/ovs-kmod.spec /tmp/ovs-dkms.spec
./boot.sh
./configure --build=x86_64-redhat-linux-gnu --host=x86_64-redhat-linux-gnu --with-linux=/lib/modules/\${K_VERSION}/build --program-prefix= --disable-dependency-tracking --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include --libdir=/usr/lib64 --libexecdir=/usr/libexec --localstatedir=/var --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info --enable-libcapng --enable-ssl --with-pkidir=/var/lib/openvswitch/pki PYTHON=/usr/bin/python2
make rpm-fedora RPMBUILD_OPT="--without check"
# Build dkms only for now
# make rpm-fedora-kmod RPMBUILD_OPT='-D "kversion \${K_VERSION}"'
rpmbuild -D "_topdir \$(pwd)/rpm/rpmbuild" -bb --without check rhel/openvswitch-dkms.spec

mkdir -p /tmp/ovs_rpms
cp -r rpm/rpmbuild/RPMS/* /tmp/ovs_rpms/

popd
rm -rf \${TMP}
EOF

    scp "${WORKSPACE}"/build_ovs.sh "${ip}":/tmp
    ${SSH} "${ip}" " bash /tmp/build_ovs.sh >> /tmp/install_ovs.txt 2>&1"
    scp -r "${ip}":/tmp/ovs_rpms/* "${rpm_path}/"
    ${SSH} "${ip}" "rm -rf /tmp/ovs_rpms"
}

# Install OVS RPMs from yum repo
function install_ovs_from_repo() {
    local -r ip=$1
    local -r rpm_repo="$2"

    echo "Installing OVS from repo ${rpm_repo} on ${ip} ..."
    cat > "${WORKSPACE}"/install_ovs.sh << EOF
set -ex -o pipefail

echo '---> Installing openvswitch from ${rpm_repo}'

# We need repoquery from yum-utils.
sudo yum -y install yum-utils

# Get openvswitch packages offered by custom repo.
# dkms package will have priority over kmod.
OVS_REPO_OPTS="--repofrompath=ovs-repo,${rpm_repo} --disablerepo=* --enablerepo=ovs-repo"
OVS_PKGS=\$(repoquery \${OVS_REPO_OPTS} openvswitch)
OVS_SEL_PKG=\$(repoquery \${OVS_REPO_OPTS} openvswitch-selinux-policy)
OVS_DKMS_PKG=\$(repoquery \${OVS_REPO_OPTS} openvswitch-dkms)
OVS_KMOD_PKG=\$(repoquery \${OVS_REPO_OPTS} openvswitch-kmod)
[ -n "\${OVS_SEL_PKG}" ] && OVS_PKGS="\${OVS_PKGS} \${OVS_SEL_PKG}"
[ -n "\${OVS_DKMS_PKG}" ] && OVS_PKGS="\${OVS_PKGS} \${OVS_DKMS_PKG}"
[ -z "\${OVS_DKMS_PKG}" ] && [ -n "\${OVS_KMOD_PKG}" ] && OVS_PKGS="\${OVS_PKGS} \${OVS_KMOD_PKG}"

# Bail with error if custom repo was provided but we could not
# find suitable packages there.
[ -z "\${OVS_PKGS}" ] && echo "No OVS packages found in custom repo." && exit 1

# Install kernel & devel packages for the openvswitch dkms package.
if [ -n "\${OVS_DKMS_PKG}" ]; then
    # install centos-release to update vault repos from which to fetch
    # kernel devel packages
    sudo yum -y install centos-release
    K_VERSION=\$(uname -r)
    YUM_OPTS="-y --disablerepo=* --enablerepo=base,updates,extra,C*-base,C*-updates,C*-extras"
    sudo yum \${YUM_OPTS} install kernel-{headers,devel}-\${K_VERSION} @'Development Tools' python-six
fi

PREV_MOD=\$(sudo modinfo -n openvswitch || echo '')

# Install OVS offered by custom repo.
sudo yum-config-manager --add-repo "${rpm_repo}"
sudo yum -y versionlock delete openvswitch-*
sudo yum -y remove openvswitch-*
sudo yum -y --nogpgcheck install \${OVS_PKGS}
sudo yum -y versionlock add \${OVS_PKGS}

# Most recent OVS versions have some incompatibility with certain versions of iptables
# This below line will overcome that problem.
sudo modprobe openvswitch

# Start OVS and print details
sudo systemctl start openvswitch
sudo systemctl enable openvswitch
sudo ovs-vsctl --retry -t 5 show
sudo modinfo openvswitch

# dkms rpm install can fail silently (probably because the OVS version is
# incompatible with the running kernel), verify module was updated.
NEW_MOD=\$(sudo modinfo -n openvswitch || echo '')
[ "\${PREV_MOD}" != "\${NEW_MOD}" ] || (echo "Kernel module was not updated" && exit 1)
EOF

    scp "${WORKSPACE}"/install_ovs.sh "${ip}":/tmp
    ${SSH} "${ip}" "bash /tmp/install_ovs.sh >> /tmp/install_ovs.txt 2>&1"
}

# Install OVS RPMS from path
function install_ovs_from_path() {
    local -r ip=$1
    local -r rpm_path="$2"

    echo "Creating OVS RPM repo on ${ip} ..."
    ${SSH} "${ip}" "mkdir -p /tmp/ovs_rpms"
    scp -r "${rpm_path}"/* "${ip}":/tmp/ovs_rpms
    ${SSH} "${ip}" "sudo yum -y install createrepo && createrepo --database /tmp/ovs_rpms"
    install_ovs_from_repo "${ip}" file:/tmp/ovs_rpms
}


