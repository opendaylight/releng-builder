#!/bin/bash

# Copy the whole script to /tmp/common-functions.sh and to remote nodes but
# only if this script itself is executing and not sourced.
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    echo "Copying common-functions.sh to /tmp"
    cp "${0}" /tmp/common-functions.sh

    [ "$NUM_OPENSTACK_SITES" ] || NUM_OPENSTACK_SITES=1
    NUM_ODLS_PER_SITE=$((NUM_ODL_SYSTEM / NUM_OPENSTACK_SITES))
    for i in `seq 1 ${NUM_OPENSTACK_SITES}`; do
        for j in `seq 1 ${NUM_ODLS_PER_SITE}`; do
            odl_ip=ODL_SYSTEM_$(((i - 1) * NUM_ODLS_PER_SITE + j))_IP
            echo "Copying common-functions.sh to ${!odl_ip}:/tmp"
            scp /tmp/common-functions.sh ${!odl_ip}:/tmp
        done
    done
    # TODO: add copy to openstack systems when needed
    exit 0
fi
