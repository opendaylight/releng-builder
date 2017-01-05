# Get the Controller and Tools VM slave addresses

ODL_SYSTEM=()
TOOLS_SYSTEM=()
OPENSTACK_SYSTEM=()

echo "JCLOUDS IPS are ${JCLOUDS_IPS}"

IFS=',' read -ra ADDR <<< "${JCLOUDS_IPS}"

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
   echo "NUM_OPENSTACK_SYSTEM=$(( ${#OPENSTACK_SYSTEM[@]} - ${NUM_OPENSTACK_SITES} ))" >> slave_addresses.txt
else
   echo "NUM_OPENSTACK_SYSTEM=${#OPENSTACK_SYSTEM[@]}" >> slave_addresses.txt
fi

for j in `seq 0 $(( ${NUM_OPENSTACK_SITES} - 1 ))`
do

    for i in `seq 1 $(( ${#ODL_SYSTEM[@]} / ${NUM_OPENSTACK_SITES} ))`
    do
        echo "SITE_$((j+1))_ODL_SYSTEM_${i}_IP=${ODL_SYSTEM[$((j+i-1))]}" >> slave_addresses.txt
    done


    for i in `seq 1 $(( ${#TOOLS_SYSTEM[@]} / ${NUM_OPENSTACK_SITES} ))`
    do
        echo "SITE_$((j+1))_TOOLS_SYSTEM_${i}_IP=${TOOLS_SYSTEM[$((j+i-1))]}" >> slave_addresses.txt
    done

    for i in `seq 1 $(( ${#OPENSTACK_SYSTEM[@]} / ${NUM_OPENSTACK_SITES} ))`
    do
        if [ $(( $i % (${#OPENSTACK_SYSTEM[@]} / ${NUM_OPENSTACK_SITES}) )) == 1 ]; then
            echo "SITE_$((j+1))_OPENSTACK_CONTROL_NODE_1_IP=${OPENSTACK_SYSTEM[$((j+i-1))]}" >> slave_addresses.txt
        fi
        echo "SITE_$((j+1))_OPENSTACK_COMPUTE_NODE_${i}_IP=${OPENSTACK_SYSTEM[$((j+i))]}" >> slave_addresses.txt
    done
done
# vim: sw=4 ts=4 sts=4 et ft=sh :
