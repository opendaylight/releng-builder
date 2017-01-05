# Get the Controller and Tools VM slave addresses

ODL_SYSTEM=()
TOOLS_SYSTEM=()
OPENSTACK_SYSTEM=()
[ "$NUM_OPENSTACK_SITES" ] || NUM_OPENSTACK_SITES=1

source $WORKSPACE/.venv-openstack/bin/activate
ADDR=(`openstack stack show -f json -c outputs $STACK_NAME | \
       jq -r '.outputs[] | \
              select(.output_key | match("^vm_[0-9]+_ips$")) | \
              .output_value | .[]'`)

for i in "${ADDR[@]}"
do
    REMHOST=`ssh ${i} hostname`
    case ${REMHOST} in
    *java*)
       ODL_SYSTEM=( "${ODL_SYSTEM[@]}" "${i}" )
       ;;
    *devstack*)
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
   NUM_OPENSTACK_SYSTEM=$(( ${#OPENSTACK_SYSTEM[@]} - ${NUM_OPENSTACK_SITES} ))
else
   NUM_OPENSTACK_SYSTEM=${#OPENSTACK_SYSTEM[@]}
fi
echo "NUM_OPENSTACK_SYSTEM=${NUM_OPENSTACK_SYSTEM}" >> slave_addresses.txt

# Add alias for ODL_SYSTEM_1_IP as ODL_SYSTEM_IP
echo "ODL_SYSTEM_IP=${ODL_SYSTEM[0]}" >> slave_addresses.txt
for i in `seq 0 $(( ${#ODL_SYSTEM[@]} - 1 ))`
do
    echo "ODL_SYSTEM_$((i+1))_IP=${ODL_SYSTEM[${i}]}" >> slave_addresses.txt
done

# Add alias for TOOLS_SYSTEM_1_IP as TOOLS_SYSTEM_IP
echo "TOOLS_SYSTEM_IP=${TOOLS_SYSTEM[0]}" >> slave_addresses.txt
for i in `seq 0 $(( ${#TOOLS_SYSTEM[@]} - 1 ))`
do
    echo "TOOLS_SYSTEM_$((i+1))_IP=${TOOLS_SYSTEM[${i}]}" >> slave_addresses.txt
done

openstack_index=0
# Assuming number of openstack control nodes equals number of openstack sites
NUM_OPENSTACK_CONTROL_NODES=$(( NUM_OPENSTACK_SITES ))
echo "NUM_OPENSTACK_CONTROL_NODES=${NUM_OPENSTACK_CONTROL_NODES}" >> slave_addresses.txt
for i in `seq 0 $((NUM_OPENSTACK_CONTROL_NODES - 1))`
do
    echo "OPENSTACK_CONTROL_NODE_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done

# The rest of the openstack nodes until NUM_OPENSTACK_SYSTEM are computes
NUM_OPENSTACK_COMPUTE_NODES=$(( NUM_OPENSTACK_SYSTEM - NUM_OPENSTACK_CONTROL_NODES ))
echo "NUM_OPENSTACK_COMPUTE_NODES=${NUM_OPENSTACK_COMPUTE_NODES}" >> slave_addresses.txt
for i in `seq 0 $((NUM_OPENSTACK_COMPUTE_NODES - 1))`
do
    echo "OPENSTACK_COMPUTE_NODE_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done

# The remaining openstack nodes are haproxy nodes (for ODL cluster)
NUM_OPENSTACK_HAPROXY_NODES=$(( ${#OPENSTACK_SYSTEM[@]} - NUM_OPENSTACK_SYSTEM ))
echo "NUM_OPENSTACK_HAPROXY_NODES=${NUM_OPENSTACK_HAPROXY_NODES}" >> slave_addresses.txt
for i in `seq 0 $((NUM_OPENSTACK_HAPROXY_NODES - 1))`
do
    echo "OPENSTACK_HAPROXY_$((i+1))_IP=${OPENSTACK_SYSTEM[$((openstack_index++))]}" >> slave_addresses.txt
done
# vim: sw=4 ts=4 sts=4 et ft=sh :
