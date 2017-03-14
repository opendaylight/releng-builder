# Get the Controller and Tools VM slave addresses

ODL_SYSTEM=()
TOOLS_SYSTEM=()
OPENSTACK_SYSTEM=()

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
   echo "NUM_OPENSTACK_SYSTEM=$(( ${#OPENSTACK_SYSTEM[@]} - 1 ))" >> slave_addresses.txt
else
   echo "NUM_OPENSTACK_SYSTEM=${#OPENSTACK_SYSTEM[@]}" >> slave_addresses.txt
fi

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

echo "OPENSTACK_CONTROL_NODE_IP=${OPENSTACK_SYSTEM[0]}" >> slave_addresses.txt
for i in `seq 1 $(( ${#OPENSTACK_SYSTEM[@]} - 1 ))`
do
    echo "OPENSTACK_COMPUTE_NODE_$((i))_IP=${OPENSTACK_SYSTEM[${i}]}" >> slave_addresses.txt
done
# vim: sw=4 ts=4 sts=4 et ft=sh :
