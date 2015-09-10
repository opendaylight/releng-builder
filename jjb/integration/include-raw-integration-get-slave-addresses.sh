# Get the Controller and Tools VM slave addresses

CONTROLLER=()
TEST_PARTNER=()

IFS=',' read -ra ADDR <<< "${JCLOUDS_IPS}"

for i in "${ADDR[@]}"
do
    REMHOST=`ssh ${i} hostname`
    if [ `echo ${REMHOST} | grep java` ]; then
        CONTROLLER=( "${CONTROLLER[@]}" "${i}" )
    else
        TOOLS_SYSTEM=( "${TOOLS_SYSTEM[@]}" "${i}" )
    fi
done

# Add alias for CONTROLLER_1 as CONTROLLER
echo "CONTROLLER_IP=${CONTROLLER[${0}]}" >> slave_addresses.txt
for i in `seq 0 $(( ${#CONTROLLER[@]} - 1 ))`
do
    echo "CONTROLLER_${i+1}_IP=${CONTROLLER[${i}]}" >> slave_addresses.txt
done

# Add alias for TOOLS_SYSTEM_1 as TOOLS_SYSTEM
echo "TOOLS_SYSTEM_IP=${TOOLS_SYSTEM[${0}]}" >> slave_addresses.txt
for i in `seq 0 $(( ${#TOOLS_SYSTEM[@]} - 1 ))`
do
    echo "TOOLS_SYSTEM_${i+1}_IP=${TOOLS_SYSTEM[${i}]}" >> slave_addresses.txt
done

# vim: sw=4 ts=4 sts=4 et ft=sh :
