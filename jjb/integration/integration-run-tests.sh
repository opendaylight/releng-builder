#!/bin/bash -l
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

sudo pip install -U python-openstackclient

USER=heat-admin
openstack object save OPNFV-APEX-SNAPSHOTS overcloudrc
source overcloudrc
cat overcloudrc
openstack hypervisor list

git clone https://gerrit.opnfv.org/gerrit/releng.git /tmp/opnfv_releng
# Extra Configs needed for CSIT:
wget -O ${WORKSPACE}/cirros-0.3.5-x86_64-disk.img http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ${OPENSTACK_CONTROL_NODE_1_IP}, -u heat-admin --key-file /tmp/id_rsa /tmp/opnfv_releng/jjb/cperf/cirros-upload.yaml.ansible -vvv

ssh ${OPENSTACK_CONTROL_NODE_1_IP} "
    sudo setenforce 0
    sudo iptables -I INPUT -p udp -m multiport --dports 4789,9876 -j ACCEPT
    sudo iptables --line-numbers -nvL
"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "
    sudo setenforce 0
    sudo iptables -I INPUT -p udp -m multiport --dports 4789,9876 -j ACCEPT
    sudo iptables --line-numbers -nvL
"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "
    sudo setenforce 0
    sudo iptables -I INPUT -p udp -m multiport --dports 4789,9876 -j ACCEPT
    sudo iptables --line-numbers -nvL
"

# Create tunnels between computes and controls so that vlan networks can work.
# there seems to be some bug in the infra preventing tagged traffic from
# working without tunneling them, making our vlan network suites fail
# Computes

ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo ovs-vsctl show"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "sudo ovs-vsctl show"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "sudo ovs-vsctl show"

PHYSNET_WORK=datacentre
BR_WORK=br-${PHYSNET_WORK}
ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:01"

ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:02"

ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:03"

ssh ${OPENSTACK_CONTROL_NODE_1_IP} "
        sudo ovs-vsctl add-port ${BR_WORK} compute_1_vxlan -- set interface compute_1_vxlan type=vxlan options:local_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:remote_ip=${OPENSTACK_COMPUTE_NODE_1_IP} options:dst_port=9876 options:key=flow
"
ssh ${OPENSTACK_CONTROL_NODE_1_IP} "
    sudo ovs-vsctl add-port ${BR_WORK} compute_2_vxlan -- set interface compute_2_vxlan type=vxlan options:local_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:remote_ip=${OPENSTACK_COMPUTE_NODE_2_IP} options:dst_port=9876 options:key=flow
"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "
        sudo ovs-vsctl add-port ${BR_WORK} control_1_vxlan -- set interface control_1_vxlan type=vxlan options:local_ip=${OPENSTACK_COMPUTE_NODE_1_IP} options:remote_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:dst_port=9876 options:key=flow
"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "
        sudo ovs-vsctl add-port ${BR_WORK} control_1_vxlan -- set interface control_1_vxlan type=vxlan options:local_ip=${OPENSTACK_COMPUTE_NODE_2_IP} options:remote_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:dst_port=9876 options:key=flow
"

ssh ${OPENSTACK_CONTROL_NODE_1_IP} "sudo ovs-vsctl show"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "sudo ovs-vsctl show"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "sudo ovs-vsctl show"

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
    -v DEFAULT_LINUX_PROMPT:\$ \
    -v DEFAULT_LINUX_PROMPT_STRICT:]\$ \
    -v DEFAULT_USER:${USER} \
    -v ENABLE_ITM_DIRECT_TUNNELS:${ENABLE_ITM_DIRECT_TUNNELS} \
    -v EXTERNAL_GATEWAY:$CONTROLLER_1_IP \
    -v EXTERNAL_PNF:$CONTROLLER_1_IP \
    -v EXTERNAL_SUBNET:192.0.2.0/24 \
    -v EXTERNAL_SUBNET_ALLOCATION_POOL:start=192.0.2.100,end=192.0.2.200 \
    -v EXTERNAL_INTERNET_ADDR:$CONTROLLER_1_IP  \
    -v HA_PROXY_IP:$ODL_SYSTEM_IP \
    -v JDKVERSION:${JDKVERSION} \
    -v JENKINS_WORKSPACE:${WORKSPACE} \
    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
    -v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} \
    -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
    -v ODL_RESTCONF_PASSWORD:$SDN_CONTROLLER_PASSWORD \
    -v ODL_SNAT_MODE:${ODL_SNAT_MODE} \
    -v ODL_STREAM:${DISTROSTREAM} \
    -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
    -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} \
    -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OS_CONTROL_NODE_1_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OPENSTACK_BRANCH:${OPENSTACK_BRANCH} \
    -v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} \
    -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
    -v OPENSTACK_TOPO:${OPENSTACK_TOPO} \
    -v OS_USER:${USER} \
    -v PUBLIC_PHYSICAL_NETWORK:${PHYSNET_WORK} \
    -v RESTCONFPORT:8081 \
    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
    -v SSH_KEY:robot_id_rsa \
    -v USER_HOME:${HOME} \
    -v WORKSPACE:/tmp \
    ${TESTOPTIONS} ${suite} || true
done
#rebot exit codes seem to be different
rebot --output ${WORKSPACE}/output.xml --log log_full.html --report report.html -N openstack output_*.xml || true

echo "Collecting logs"
mkdir -p ${WORKSPACE}/archives

ssh ${ODL_SYSTEM_IP} "mkdir /tmp/controller_sos; sudo sosreport --batch --build --tmp-dir /tmp/controller_sos/ --name controller_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh ${ODL_SYSTEM_IP} "sudo chmod -R 0777 /tmp/controller_sos/; tar cvzf /tmp/controller_sos.tar.gz /tmp/controller_sos"
scp ${ODL_SYSTEM_IP}:/tmp/controller_sos.tar.gz ${WORKSPACE}/archives/controller_sos.tar.gz

ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "mkdir /tmp/compute_1_sos; sudo sosreport --batch --build --tmp-dir /tmp/compute_1_sos/ --name compute_1_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh ${OPENSTACK_COMPUTE_NODE_1_IP} "sudo chmod -R 0777 /tmp/compute_1_sos/; tar cvzf /tmp/compute_1_sos.tar.gz /tmp/compute_1_sos"
scp ${OPENSTACK_COMPUTE_NODE_1_IP}:/tmp/compute_1_sos.tar.gz ${WORKSPACE}/archives/compute_1_sos.tar.gz

ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "mkdir /tmp/compute_2_sos; sudo sosreport --batch --build --tmp-dir /tmp/compute_2_sos/ --name compute_2_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh ${OPENSTACK_COMPUTE_NODE_2_IP} "sudo chmod -R 0777 /tmp/compute_2_sos/; tar cvzf /tmp/compute_2_sos.tar.gz /tmp/compute_2_sos"
scp ${OPENSTACK_COMPUTE_NODE_2_IP}:/tmp/compute_2_sos.tar.gz ${WORKSPACE}/archives/compute_2_sos.tar.gz

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
