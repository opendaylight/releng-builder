#!/bin/bash -l
# Get the Controller and Tools VM slave addresses

set -x -o pipefail -o errexit

git clone https://gerrit.opnfv.org/gerrit/releng.git

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
ODL_SYSTEM_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type controller --file node.yaml)
OPENSTACK_COMPUTE_NODE_1_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 1 --file node.yaml)
OPENSTACK_COMPUTE_NODE_2_IP=$(python releng/jjb/cperf/parse-node-yaml.py get_value -k address --node-type compute --node-number 2 --file node.yaml)
OPENSTACK_CONTROL_NODE_1_IP=$ODL_SYSTEM_IP
ODL_SYSTEM_1_IP=$ODL_SYSTEM_IP

echo "NUM_OPENSTACK_SYSTEM=$NUM_OPENSTACK_SYSTEM" >> slave_addresses.txt
echo "NUM_ODL_SYSTEM=$NUM_ODL_SYSTEM" >> slave_addresses.txt
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


# ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo ovs-vsctl set Open_vSwitch . other_config:provider_mappings=datacentre:br-datacentre"
# ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo ovs-vsctl set Open_vSwitch . other_config:provider_mappings=datacentre:br-datacentre"
# ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo ovs-vsctl set Open_vSwitch . other_config:provider_mappings=datacentre:br-datacentre"

cat > /tmp/br_work.sh << EOF
sudo jq -c '. + {"neutron::plugins::ovs::opendaylight::provider_mappings": ["datacentre:br-datacentre"]}' /etc/puppet/hieradata/config_step.json > tmp.$$.json && mv -f tmp.$$.json /etc/puppet/hieradata/config_step.json
sudo puppet apply -e 'include tripleo::profile::base::neutron::plugins::ovs::opendaylight' -v
EOF
echo "cat br_work.sh"
cat /tmp/br_work.sh

scp /tmp/br_work.sh  $OPENSTACK_CONTROL_NODE_1_IP:/tmp
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo bash /tmp/br_work.sh"
scp /tmp/br_work.sh  $OPENSTACK_COMPUTE_NODE_1_IP:/tmp
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo bash /tmp/br_work.sh"
scp /tmp/br_work.sh  $OPENSTACK_COMPUTE_NODE_2_IP:/tmp
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo bash /tmp/br_work.sh"

# JAMO
# Change interface MTU to account for default network mtu of 1458
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo /usr/sbin/ip link set dev eth0 mtu 1458"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo /usr/sbin/ip link set dev br-int mtu 1458"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo /usr/sbin/ip link set dev br-ex mtu 1458"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo /usr/sbin/ip link set dev docker0 mtu 1458"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo /usr/sbin/ip link set dev ovs-system mtu 1458"

ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo /usr/sbin/ip link set dev eth0 mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo /usr/sbin/ip link set dev br-int mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo /usr/sbin/ip link set dev br-ex mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo /usr/sbin/ip link set dev docker0 mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo /usr/sbin/ip link set dev ovs-system mtu 1458"

ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo /usr/sbin/ip link set dev eth0 mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo /usr/sbin/ip link set dev br-int mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo /usr/sbin/ip link set dev br-ex mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo /usr/sbin/ip link set dev docker0 mtu 1458"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo /usr/sbin/ip link set dev ovs-system mtu 1458"

ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#physical_network_mtus =/physical_network_mtus = datacentre:1458/' /etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#physical_network_mtus =/physical_network_mtus = datacentre:1458/' /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#physical_network_mtus =/physical_network_mtus = datacentre:1458/' /var/lib/config-data/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/^path_mtu=0.*//' /etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/^path_mtu=0.*//' /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/^path_mtu=0.*//' /var/lib/config-data/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"

ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#path_mtu.*/path_mtu = 1458/' /etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#path_mtu.*/path_mtu = 1458/' /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#path_mtu.*/path_mtu = 1458/' /var/lib/config-data/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"


ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/^global_physnet_mtu.*//' /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#global_physnet_mtu.*/global_physnet_mtu = 1458/' /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#global_physnet_mtu.*/global_physnet_mtu = 1458/' /etc/neutron/neutron.conf"

ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#debug = false/debug = true/' /var/lib/config-data/puppet-generated/neutron/etc/neutron/dhcp_agent.ini"
ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/#debug = false/debug = true/' /etc/neutron/dhcp_agent.ini"

ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo docker restart neutron_api; sudo docker restart neutron_dhcp; sudo docker restart neutron_db_sync"


ssh $OPENSTACK_CONTROL_NODE_1_IP "sudo sed -i 's/network_vlan_ranges=datacentre:500:525/network_vlan_ranges=datacentre:1:4094/' /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"

ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo sed -i 's/virt_type=.*/virt_type=qemu/' /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo sed -i 's/virt_type=.*/virt_type=qemu/' /var/lib/config-data/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo docker restart nova_compute"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo docker restart nova_libvirt"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo cat /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_1_IP "sudo cat /var/lib/config-data/nova_libvirt/etc/nova/nova.conf"

ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo cat /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo cat /var/lib/config-data/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo sed -i 's/virt_type=.*/virt_type=qemu/' /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo sed -i 's/virt_type=.*/virt_type=qemu/' /var/lib/config-data/nova_libvirt/etc/nova/nova.conf"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo docker restart nova_compute"
ssh $OPENSTACK_COMPUTE_NODE_2_IP "sudo docker restart nova_libvirt"

# vim: sw=4 ts=4 sts=4 et ft=sh :


