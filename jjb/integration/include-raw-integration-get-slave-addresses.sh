# Get the Controller and Tools VM slave addresses

ODL_SYSTEM=()
TOOLS_SYSTEM=()

IFS=',' read -ra ADDR <<< "${JCLOUDS_IPS}"

for i in "${ADDR[@]}"
do
    REMHOST=`ssh ${i} hostname`
    if [ `echo ${REMHOST} | grep java` ]; then
        ODL_SYSTEM=( "${ODL_SYSTEM[@]}" "${i}" )
    else
        TOOLS_SYSTEM=( "${TOOLS_SYSTEM[@]}" "${i}" )
    fi
done

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

# vim: sw=4 ts=4 sts=4 et ft=sh :
