#!/bin/bash -l
# Get the Controller and Tools VM slave addresses

set -x -o pipefail -o errexit

OPENSTACK_VENV="/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source $OPENSTACK_VENV/bin/activate

git clone https://gerrit.opnfv.org/gerrit/releng.git

openstack object save OPNFV-APEX-SNAPSHOTS node.yaml
openstack object save OPNFV-APEX-SNAPSHOTS id_rsa --file ~/.ssh/id_rsa

NUM_OPENSTACK_SYSTEMS=3
ODL_SYSTEM_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type controller --file node.yaml)
OPENSTACK_COMPUTE_NODE_1_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 1 --file node.yaml)
OPENSTACK_COMPUTE_NODE_2_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 2 --file node.yaml)
OPENSTACK_CONTROL_NODE_1_IP=$ODL_SYSTEM_IP
ODL_SYSTEM_1_IP=$ODL_SYSTEM_IP

echo "NUM_OPENSTACK_SYSTEMS=$NUM_OPENSTACK_SYSTEMS" >> slave_addresses.txt
echo "ODL_SYSTEM_IP=$ODL_SYSTEM_IP" >> slave_addresses.txt
echo "OPENSTACK_COMPUTE_NODE_1_IP=$OPENSTACK_COMPUTE_NODE_1_IP" >> slave_addresses.txt
echo "OPENSTACK_COMPUTE_NODE_2_IP=$OPENSTACK_COMPUTE_NODE_2_IP" >> slave_addresses.txt
echo "OPENSTACK_CONTROL_NODE_1_IP=$OPENSTACK_CONTROL_NODE_1_IP" >> slave_addresses.txt
echo "ODL_SYSTEM_1_IP=$ODL_SYSTEM_1_IP" >> slave_addresses.txt

cat slave_addresses.txt

# Add Robot builder to new Apex network (adding 2nd nic)
JOB_SUM=$(echo "$JOB_NAME" | sum | awk '{ print $1 }')
VM_NAME="$JOB_SUM-$BUILD_NUMBER"
SERVER_ID=$(openstack server show -f value -c id $(hostname -s))
NETWORK_ID=$(openstack network show -f value -c id "$SILO-$VM_NAME-APEX_192_network")
openstack server add network $SERVER_ID $NETWORK_ID
ETH1_MAC=$(ip address show eth1 | grep ether | awk -F' ' '{print $2}')
ETH1_SCRIPT="/etc/sysconfig/network-scripts/ifcfg-eth1"
sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 "$ETH1_SCRIPT"
sudo sed -i "s/eth0/eth1/; s/^HWADDR=.*/HWADDR=$ETH1_MAC/" "$ETH1_SCRIPT"
sudo echo 'PEERDNS=no' | sudo tee -a "$ETH1_SCRIPT"
sudo echo 'DEFROUTE=no' | sudo tee -a "$ETH1_SCRIPT"
cat "$ETH1_SCRIPT"
sudo ifup eth1
ip a

echo "Testing Connectivity To Apex Systems"
ping -c3 "$OPENSTACK_CONTROL_NODE_1_IP"
ping -c3 "$OPENSTACK_COMPUTE_NODE_1_IP"
ping -c3 "$OPENSTACK_COMPUTE_NODE_2_IP"

# vim: sw=4 ts=4 sts=4 et ft=sh :


