#!/bin/bash -l
# Get the Controller and Tools VM slave addresses

set -ex -o pipefail

git clone https://gerrit.opnfv.org/gerrit/releng.git /tmp/opnfv_releng

openstack object save OPNFV-APEX-SNAPSHOTS node.yaml
openstack object save OPNFV-APEX-SNAPSHOTS id_rsa --file /tmp/id_rsa
cat > ~/.ssh/config <<EOF
Host 192.0.2.*
  User heat-admin
  IdentityFile /tmp/id_rsa
EOF
ln -s /tmp/id_rsa ~/.ssh/robot_id_rsa
chmod 0600 /tmp/id_rsa ~/.ssh/config

NUM_OPENSTACK_SYSTEM=3
NUM_ODL_SYSTEM=1
ODL_SYSTEM_IP=$(python /tmp/opnfv_releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type controller --file node.yaml)
OPENSTACK_COMPUTE_NODE_1_IP=$(python /tmp/opnfv_releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 1 --file node.yaml)
OPENSTACK_COMPUTE_NODE_2_IP=$(python /tmp/opnfv_releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 2 --file node.yaml)
OPENSTACK_CONTROL_NODE_1_IP=$ODL_SYSTEM_IP
ODL_SYSTEM_1_IP=$ODL_SYSTEM_IP

# shellcheck disable=SC2129
echo "NUM_OPENSTACK_SYSTEM=$NUM_OPENSTACK_SYSTEM" >> slave_addresses.txt
echo "NUM_ODL_SYSTEM=$NUM_ODL_SYSTEM" >> slave_addresses.txt
echo "ODL_SYSTEM_IP=$ODL_SYSTEM_IP" >> slave_addresses.txt
echo "CONTROLLER_1_IP=$ODL_SYSTEM_IP" >> slave_addresses.txt

echo "OPENSTACK_COMPUTE_NODE_1_IP=$OPENSTACK_COMPUTE_NODE_1_IP" >> slave_addresses.txt
echo "OPENSTACK_COMPUTE_NODE_2_IP=$OPENSTACK_COMPUTE_NODE_2_IP" >> slave_addresses.txt
echo "OPENSTACK_CONTROL_NODE_1_IP=$OPENSTACK_CONTROL_NODE_1_IP" >> slave_addresses.txt
echo "ODL_SYSTEM_1_IP=$ODL_SYSTEM_1_IP" >> slave_addresses.txt

cat slave_addresses.txt

# Add Robot builder to new Apex network (adding 2nd nic). The Apex snapshots
# have a single nic with a static ip on the 192.0.2.0/24 network. The eth0
# nic on the robot builders come up on the standard 10 net from our cloud
# infra. To give connectivity between the robot builder and the apex vms,
# a new network is created for the 192.0.2.0/subnet and this second nic is
# added to that network. DHCP is used for the robot builder in a range outside
# of what any apex ip address would be.
JOB_SUM=$(echo "$JOB_NAME" | sum | awk '{ print $1 }')
VM_NAME="$JOB_SUM-$BUILD_NUMBER"
SERVER_ID="$(openstack server show -f value -c id "$(hostname -s)")"
NETWORK_ID="$(openstack network show -f value -c id "$SILO-$VM_NAME-APEX_192_network")"
openstack server add network "$SERVER_ID" "$NETWORK_ID"
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


