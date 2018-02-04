#!/bin/bash
# Get the Controller and Tools VM slave addresses

set -x

ODL_SYSTEM=()
TOOLS_SYSTEM=()
OPENSTACK_SYSTEM=()
OPENSTACK_CONTROLLERS=()
[ "$NUM_OPENSTACK_SITES" ] || NUM_OPENSTACK_SITES=1

OPENSTACK_VENV="/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source $OPENSTACK_VENV/bin/activate
mapfile -t ADDR <<< "$(openstack stack show -f json -c outputs "$STACK_NAME" | jq -r '.outputs[] | select(.output_key | match("^vm_[0-9]+_ips$")) | .output_value | .[]')"

# The next two blocks of code will parse the list of vm IP's hostnames to determine which type of node
# the vm is: odl, devstack controller or compute, ha_proxy or tools. For the odl node's the hsotname will contain
# java in the name. The tools nodes are anything left after odl and devstack nodes have been found.
#
# The devstack nodes are identified with devstack in the hostname but require more checks to determine the controller
# node. Heat names the vms as devstack-<index> with index starting at 0. The vms are created in groups of which
# the openstack jobs create a vm_1_group for the controller and vm_2_group for the other vms such as the compute
# and ha_proxy nodes. The list of IP addresses for all the created vms is returned in reverse order of the group
# creation, but ordered within the group. I.E vm_1_group will be created first and named devstack-0, followed by
# vm_2_group and named devstack-0, devstack-1 and devstack-2. The list of IPs will be: devstack-0 (vm_2_group, compute),
# devstack-1, devstack-2, devstack-0 (vm_1_group, controller). Notice both the compute and first control node are both
# named devstack-0. We know the controller because it would be last in the list of IPs. This first block of code will
# produce two lists: one for the list of potential controllers and the second is a list of all devstack nodes.

for i in "${ADDR[@]}"
do
    REMHOST=$(ssh "${i}" hostname -s)
    case ${REMHOST} in
    *builder*)
       ODL_SYSTEM=( "${ODL_SYSTEM[@]}" "${i}" )
       ;;
    *devstack*)
       # track potential controllers which would have -0 at the end of the hostname
       if [[ ${REMHOST: -2} == "-0" ]]; then
          OPENSTACK_CONTROLLERS=( "${OPENSTACK_CONTROLLERS[@]}" "${i}" )
       fi

       OPENSTACK_SYSTEM=( "${OPENSTACK_SYSTEM[@]}" "${i}" )
       ;;
    *)
       TOOLS_SYSTEM=( "${TOOLS_SYSTEM[@]}" "${i}" )
       ;;
    esac
done

echo "NUM_ODL_SYSTEM=${#ODL_SYSTEM[@]}" >> slave_addresses.txt
echo "NUM_TOOLS_SYSTEM=${#TOOLS_SYSTEM[@]}" >> slave_addresses.txt
#if HA Proxy is requested the last devstack node will be configured as haproxy
if [ "${ENABLE_HAPROXY_FOR_NEUTRON}" == "yes" ]; then
   # HA Proxy is installed on one OPENSTACK_SYSTEM VM on each site
   NUM_OPENSTACK_SYSTEM=$(( ${#OPENSTACK_SYSTEM[@]} - NUM_OPENSTACK_SITES ))
else
   NUM_OPENSTACK_SYSTEM=${#OPENSTACK_SYSTEM[@]}
fi
echo "NUM_OPENSTACK_SYSTEM=${NUM_OPENSTACK_SYSTEM}" >> slave_addresses.txt

# Rearrange the devstack node list to place the controller at the beginning of the list. The later code expects
# the list to be ordered with controller first followed by other types.
#
# At this point there is a list of potential devstack controllers as: devstack-0 (vm_2_group, compute),
# devstack-0 (vm_1_group, controller) and there is the full list with other compute or ha_proxy nodes in the middle.
# We know the controller is at the end of the devstack nodes list based on the ordering described above. Swap that entry
# with the first entry.
if [ ${#OPENSTACK_CONTROLLERS[@]} -eq 2 ]; then
    ctrl_index=${#OPENSTACK_SYSTEM[@]}
    ctrl_index=$((ctrl_index -1))
    tmp_addr=${OPENSTACK_SYSTEM[0]}
    OPENSTACK_SYSTEM[0]=${OPENSTACK_SYSTEM[$ctrl_index]}
    OPENSTACK_SYSTEM[$ctrl_index]=$tmp_addr
fi

# Add alias for ODL_SYSTEM_1_IP as ODL_SYSTEM_IP
echo "ODL_SYSTEM_IP=${ODL_SYSTEM[0]}" >> slave_addresses.txt
for i in $(seq 0 $(( ${#ODL_SYSTEM[@]} - 1 )))
do
    echo "ODL_SYSTEM_$((i+1))_IP=${ODL_SYSTEM[${i}]}" >> slave_addresses.txt
done

# Add alias for TOOLS_SYSTEM_1_IP as TOOLS_SYSTEM_IP
echo "TOOLS_SYSTEM_IP=${TOOLS_SYSTEM[0]}" >> slave_addresses.txt
for i in $(seq 0 $(( ${#TOOLS_SYSTEM[@]} - 1 )))
do
    echo "TOOLS_SYSTEM_$((i+1))_IP=${TOOLS_SYSTEM[${i}]}" >> slave_addresses.txt
done

openstack_index=0
# Assuming number of openstack control nodes equals number of openstack sites
NUM_OPENSTACK_CONTROL_NODES=$(( NUM_OPENSTACK_SITES ))
echo "NUM_OPENSTACK_CONTROL_NODES=${NUM_OPENSTACK_CONTROL_NODES}" >> slave_addresses.txt
for i in $(seq 0 $((NUM_OPENSTACK_CONTROL_NODES - 1)))
do
    echo "OPENSTACK_CONTROL_NODE_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done

# The rest of the openstack nodes until NUM_OPENSTACK_SYSTEM are computes
NUM_OPENSTACK_COMPUTE_NODES=$(( NUM_OPENSTACK_SYSTEM - NUM_OPENSTACK_CONTROL_NODES ))
echo "NUM_OPENSTACK_COMPUTE_NODES=${NUM_OPENSTACK_COMPUTE_NODES}" >> slave_addresses.txt

# Order the computes in the list so that the devstack-0 is index 1 and devstack-1 is index 2. Currently they are
# backwards because of the controller swap earlier.
if [ ${NUM_OPENSTACK_COMPUTE_NODES} -ge 2 ]; then
    tmp_addr=${OPENSTACK_SYSTEM[1]}
    OPENSTACK_SYSTEM[1]=${OPENSTACK_SYSTEM[2]}
    OPENSTACK_SYSTEM[2]=${tmp_addr}
fi

for i in $(seq 0 $((NUM_OPENSTACK_COMPUTE_NODES - 1)))
do
    echo "OPENSTACK_COMPUTE_NODE_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done

# The remaining openstack nodes are haproxy nodes (for ODL cluster)
NUM_OPENSTACK_HAPROXY_NODES=$(( ${#OPENSTACK_SYSTEM[@]} - NUM_OPENSTACK_SYSTEM ))
echo "NUM_OPENSTACK_HAPROXY_NODES=${NUM_OPENSTACK_HAPROXY_NODES}" >> slave_addresses.txt
for i in $(seq 0 $((NUM_OPENSTACK_HAPROXY_NODES - 1)))
do
    echo "OPENSTACK_HAPROXY_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done
echo "Contents of slave_addresses.txt:"
cat slave_addresses.txt
# vim: sw=4 ts=4 sts=4 et ft=sh :
