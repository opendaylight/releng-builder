#!/bin/bash
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

# vim: sw=4 ts=4 sts=4 et ft=sh :
