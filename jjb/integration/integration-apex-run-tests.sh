#!/bin/bash -l
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source "${ROBOT_VENV}/bin/activate"
source /tmp/common-functions.sh "${BUNDLEFOLDER}"
# Ensure we fail the job if any steps fail.
set -ex -o pipefail

print_job_parameters

get_os_deploy

configure_karaf_log_for_apex "$OPENSTACK_CONTROL_NODE_1_IP"
get_features
configure_odl_features_for_apex "$OPENSTACK_CONTROL_NODE_1_IP"

# Swap out the ODL distribution
DISTRO_UNDER_TEST=/tmp/odl.tar.gz
wget --progress=dot:mega "${ACTUAL_BUNDLE_URL}"
UNZIPPED_DIR=$(dirname "$(unzip -qql "${BUNDLE}" | head -n1 | tr -s ' ' | cut -d' ' -f5-)")
unzip -q "${BUNDLE}"
tar czf "${DISTRO_UNDER_TEST}" "${UNZIPPED_DIR}"
git clone https://gerrit.opnfv.org/gerrit/sdnvpn.git /tmp/sdnvpn
pushd /tmp/sdnvpn; git fetch https://gerrit.opnfv.org/gerrit/sdnvpn refs/changes/93/63293/1 && git checkout FETCH_HEAD; popd
/tmp/sdnvpn/odl-pipeline/lib/odl_reinstaller.sh --pod-config "${WORKSPACE}/node.yaml" --odl-artifact "${DISTRO_UNDER_TEST}" --ssh-key-file ~/.ssh/robot_id_rsa

cat > /tmp/extra_node_configs.sh << EOF
sudo jq -c '. + {"neutron::plugins::ovs::opendaylight::provider_mappings": ["datacentre:br-datacentre"]}' /etc/puppet/hieradata/config_step.json > tmp.$$.json && mv -f tmp.$$.json /etc/puppet/hieradata/config_step.json
sudo puppet apply -e 'include tripleo::profile::base::neutron::plugins::ovs::opendaylight' -v
sudo iptables -I INPUT -p udp -m multiport --dports 4789,9876,12345 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 12345 -j ACCEPT
sudo iptables --line-numbers -nvL
EOF
echo "cat extra_node_configs.sh"
cat /tmp/extra_node_configs.sh

scp /tmp/extra_node_configs.sh  "$OPENSTACK_CONTROL_NODE_1_IP:/tmp"
ssh "$OPENSTACK_CONTROL_NODE_1_IP" "sudo bash /tmp/extra_node_configs.sh"
scp /tmp/extra_node_configs.sh  "$OPENSTACK_COMPUTE_NODE_1_IP:/tmp"
ssh "$OPENSTACK_COMPUTE_NODE_1_IP" "sudo bash /tmp/extra_node_configs.sh"
scp /tmp/extra_node_configs.sh  "$OPENSTACK_COMPUTE_NODE_2_IP:/tmp"
ssh "$OPENSTACK_COMPUTE_NODE_2_IP" "sudo bash /tmp/extra_node_configs.sh"

USER=heat-admin
openstack object save OPNFV-APEX-SNAPSHOTS overcloudrc
source overcloudrc
cat overcloudrc
openstack hypervisor list

# Extra Configs needed for CSIT:
wget -O "${WORKSPACE}/cirros-0.3.5-x86_64-disk.img" http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i "${OPENSTACK_CONTROL_NODE_1_IP}", -u heat-admin --key-file /tmp/id_rsa /tmp/opnfv_releng/jjb/cperf/cirros-upload.yaml.ansible -vvv

PHYSNET_WORK=datacentre
BR_WORK="br-${PHYSNET_WORK}"
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:01"

# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:02"

# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "sudo ovs-vsctl --if-exists del-port br-int ${BR_WORK}"
# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "sudo ovs-vsctl --may-exist add-br ${BR_WORK} -- set bridge ${BR_WORK} other-config:disable-in-band=true other_config:hwaddr=f6:00:00:ff:01:03"

# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "
        sudo ovs-vsctl add-port ${BR_WORK} compute_1_vxlan -- set interface compute_1_vxlan type=vxlan options:local_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:remote_ip=${OPENSTACK_COMPUTE_NODE_1_IP} options:dst_port=9876 options:key=flow
"
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "
    sudo ovs-vsctl add-port ${BR_WORK} compute_2_vxlan -- set interface compute_2_vxlan type=vxlan options:local_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:remote_ip=${OPENSTACK_COMPUTE_NODE_2_IP} options:dst_port=9876 options:key=flow
"
# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "
        sudo ovs-vsctl add-port ${BR_WORK} control_1_vxlan -- set interface control_1_vxlan type=vxlan options:local_ip=${OPENSTACK_COMPUTE_NODE_1_IP} options:remote_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:dst_port=9876 options:key=flow
"
# shellcheck disable=SC2029
ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "
        sudo ovs-vsctl add-port ${BR_WORK} control_1_vxlan -- set interface control_1_vxlan type=vxlan options:local_ip=${OPENSTACK_COMPUTE_NODE_2_IP} options:remote_ip=${OPENSTACK_CONTROL_NODE_1_IP} options:dst_port=9876 options:key=flow
"

# Control Node - PUBLIC_BRIDGE will act as the external router
# Parameter values below are used in integration/test - changing them requires updates in intergration/test as well
EXTNET_GATEWAY_IP="10.10.10.250"
EXTNET_INTERNET_IP="10.9.9.9"
EXTNET_PNF_IP="10.10.10.253"
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo ifconfig ${PUBLIC_BRIDGE} up ${EXTNET_GATEWAY_IP}/24"

# Control Node - external net PNF simulation
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "
    sudo ip netns add pnf_ns;
    sudo ip link add pnf_veth0 type veth peer name pnf_veth1;
    sudo ip link set pnf_veth1 netns pnf_ns;
    sudo ip link set pnf_veth0 up;
    sudo ip netns exec pnf_ns ifconfig pnf_veth1 up ${EXTNET_PNF_IP}/24;
    sudo ovs-vsctl add-port ${PUBLIC_BRIDGE} pnf_veth0;
"
# Control Node - external net internet address simulation
# shellcheck disable=SC2029
ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "
    sudo ip tuntap add dev internet_tap mode tap;
    sudo ifconfig internet_tap up ${EXTNET_INTERNET_IP}/24;
"

ssh "${OPENSTACK_CONTROL_NODE_1_IP}" "sudo ovs-vsctl show"
ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "sudo ovs-vsctl show"
ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "sudo ovs-vsctl show"

get_test_suites SUITES

echo "Starting Robot test suites ${SUITES} ..."
# please add robot -v arguments on a single line and alphabetized
suite_num=0
for suite in ${SUITES}; do
    # prepend an incremental counter to the suite name so that the full robot log combining all the suites as is done
    # in the rebot step below will list all the suites in chronological order as rebot seems to alphabetize them
    ((suite_num = suite_num + 1))
    suite_index="$(printf %02d ${suite_num})"
    suite_name="$(basename "${suite}" | cut -d. -f1)"
    log_name="${suite_index}_${suite_name}"
    robot -N "${log_name}" \
    -c critical -e exclude -e "skip_if_${DISTROSTREAM}" -e NON_GATE \
    --log "log_${log_name}.html" --report "report_${log_name}.html" --output "output_${log_name}.xml" \
    --removekeywords wuks \
    --removekeywords name:SetupUtils.Setup_Utils_For_Setup_And_Teardown \
    --removekeywords name:SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing \
    --removekeywords name:OpenStackOperations.Add_OVS_Logging_On_All_OpenStack_Nodes \
    -v BUNDLEFOLDER:"${BUNDLEFOLDER}" \
    -v BUNDLE_URL:"${ACTUAL_BUNDLE_URL}" \
    -v CMP_INSTANCES_SHARED_PATH:/var/instances \
    -v CONTROLLERFEATURES:"${CONTROLLERFEATURES}" \
    -v CONTROLLER_USER:"${USER}" \
    -v DEFAULT_LINUX_PROMPT:\$ \
    -v DEFAULT_LINUX_PROMPT_STRICT:]\$ \
    -v DEFAULT_USER:"${USER}" \
    -v ENABLE_ITM_DIRECT_TUNNELS:"${ENABLE_ITM_DIRECT_TUNNELS}" \
    -v HA_PROXY_IP:"$ODL_SYSTEM_IP" \
    -v JDKVERSION:"${JDKVERSION}" \
    -v JENKINS_WORKSPACE:"${WORKSPACE}" \
    -v KARAF_LOG:/opt/opendaylight/data/log/karaf.log \
    -v NEXUSURL_PREFIX:"${NEXUSURL_PREFIX}" \
    -v NUM_ODL_SYSTEM:"${NUM_ODL_SYSTEM}" \
    -v NUM_OS_SYSTEM:"${NUM_OPENSTACK_SYSTEM}" \
    -v NUM_TOOLS_SYSTEM:"${NUM_TOOLS_SYSTEM}" \
    -v ODL_RESTCONF_PASSWORD:"$SDN_CONTROLLER_PASSWORD" \
    -v ODL_SNAT_MODE:"${ODL_SNAT_MODE}" \
    -v ODL_STREAM:"${DISTROSTREAM}" \
    -v ODL_SYSTEM_IP:"${ODL_SYSTEM_IP}" \
    -v ODL_SYSTEM_1_IP:"${ODL_SYSTEM_1_IP}" \
    -v OS_CONTROL_NODE_IP:"${OPENSTACK_CONTROL_NODE_1_IP}" \
    -v OS_CONTROL_NODE_1_IP:"${OPENSTACK_CONTROL_NODE_1_IP}" \
    -v OPENSTACK_BRANCH:"${OPENSTACK_BRANCH}" \
    -v OS_COMPUTE_1_IP:"${OPENSTACK_COMPUTE_NODE_1_IP}" \
    -v OS_COMPUTE_2_IP:"${OPENSTACK_COMPUTE_NODE_2_IP}" \
    -v OPENSTACK_TOPO:"${OPENSTACK_TOPO}" \
    -v OS_USER:"${USER}" \
    -v PUBLIC_PHYSICAL_NETWORK:"${PHYSNET_WORK}" \
    -v RESTCONFPORT:8081 \
    -v SECURITY_GROUP_MODE:"${SECURITY_GROUP_MODE}" \
    -v SSH_KEY:robot_id_rsa \
    -v TOOLS_SYSTEM_IP: \
    -v USER_HOME:"${HOME}" \
    -v WORKSPACE:/tmp \
    "${TESTOPTIONS}" "${suite}" || true
done
#rebot exit codes seem to be different
rebot --output "${WORKSPACE}/output.xml" --log log_full.html --report report.html -N openstack output_*.xml || true

echo "Collecting logs"
mkdir -p "${WORKSPACE}/archives"

ssh "${ODL_SYSTEM_IP}" "mkdir /tmp/controller_sos; sudo sosreport --all-logs --batch --build --tmp-dir /tmp/controller_sos/ --name controller_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh "${ODL_SYSTEM_IP}" "sudo chmod -R 0777 /tmp/controller_sos/; tar cvzf /tmp/controller_sos.tar.gz /tmp/controller_sos"
scp "${ODL_SYSTEM_IP}":/tmp/controller_sos.tar.gz "${WORKSPACE}/archives/controller_sos.tar.gz"
gunzip "${WORKSPACE}/archives/controller_sos.tar.gz"
tar -xvf "${WORKSPACE}/archives/controller_sos.tar" -C "${WORKSPACE}/archives/"

ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "mkdir /tmp/compute_1_sos; sudo sosreport --all-logs --batch --build --tmp-dir /tmp/compute_1_sos/ --name compute_1_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh "${OPENSTACK_COMPUTE_NODE_1_IP}" "sudo chmod -R 0777 /tmp/compute_1_sos/; tar cvzf /tmp/compute_1_sos.tar.gz /tmp/compute_1_sos"
scp "${OPENSTACK_COMPUTE_NODE_1_IP}":/tmp/compute_1_sos.tar.gz "${WORKSPACE}/archives/compute_1_sos.tar.gz"
gunzip "${WORKSPACE}/archives/compute_1_sos.tar.gz"
tar -xvf "${WORKSPACE}/archives/compute_1_sos.tar" -C "${WORKSPACE}/archives/"

ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "mkdir /tmp/compute_2_sos; sudo sosreport --all-logs --batch --build --tmp-dir /tmp/compute_2_sos/ --name compute_2_report -o networking,openstack_glance,openstack_neutron,openstack_nova,opendaylight,openvswitch"
ssh "${OPENSTACK_COMPUTE_NODE_2_IP}" "sudo chmod -R 0777 /tmp/compute_2_sos/; tar cvzf /tmp/compute_2_sos.tar.gz /tmp/compute_2_sos"
scp "${OPENSTACK_COMPUTE_NODE_2_IP}":/tmp/compute_2_sos.tar.gz "${WORKSPACE}/archives/compute_2_sos.tar.gz"
gunzip "${WORKSPACE}/archives/compute_2_sos.tar.gz"
tar -xvf "${WORKSPACE}/archives/compute_2_sos.tar" -C "${WORKSPACE}/archives/"

mv "${WORKSPACE}"/archives/tmp/* "${WORKSPACE}/archives/"
rm -rf "${WORKSPACE}/archives/tmp"

true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
