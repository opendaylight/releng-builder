# Get the Controller and Mininet slave addresses

CONTROLLER=()
MININET=()

IFS=',' read -ra ADDR <<< "${JCLOUDS_IPS}"

for i in "${ADDR[@]}"
do
    REMHOST=`ssh ${i} hostname`
    if [ `echo ${REMHOST} | grep java` ]; then
        CONTROLLER=( "${CONTROLLER[@]}" "${i}" )
    else
        MININET=( "${MININET[@]}" "${i}" )
    fi
done

for i in `seq 0 $(( ${#CONTROLLER[@]} - 1 ))`
do
    echo "CONTROLLER${i}=${CONTROLLER[${i}]}" >> slave_addresses.txt
done

for i in `seq 0 $(( ${#MININET[@]} - 1 ))`
do
    echo "MININET${i}=${MININET[${i}]}" >> slave_addresses.txt
done

# vim: sw=4 ts=4 sts=4 et ft=sh :
