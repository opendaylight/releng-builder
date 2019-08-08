#!/bin/bash -l

# Copy the whole script to /tmp/common-functions.sh and to remote nodes but
# only if this script itself is executing and not sourced. jenkins prepends this
# script to the common-functions.sh script when adding it to the robot minion.
# jenkins will then execute the script. The if check below checks that the
# script is executing rather than being sourced. When executed the condition
# is true and copies the script. In the false path this copy below is skipped
# and the sourcing continues so that the appended common-function.sh ends up sourced.
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    echo "Copying common-functions.sh to /tmp"
    cp "${0}" /tmp/common-functions.sh

    mapfile -t ips <<< "$(openstack stack show -f json -c outputs "$STACK_NAME" | jq -r '.outputs[] | select(.output_key | match("^vm_[0-9]+_ips$")) | .output_value | .[]')"
    for ip in "${ips[@]}"; do
        echo "Copying common-functions.sh to ${ip}:/tmp"
        scp /tmp/common-functions.sh "${ip}:/tmp"
    done
    exit 0
fi
