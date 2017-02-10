#!/bin/bash
echo "----------> Copy ssh public keys to csit lab"

source $WORKSPACE/.venv-openstack/bin/activate

function copy-ssh-keys-to-slave() {
    RETRIES=60
    for j in $(seq 1 $RETRIES); do
        # ping test to see if connectivity is available
        ping -c1 ${i}

        if `ssh-copy-id -i /home/jenkins/.ssh/id_rsa.pub "jenkins@${i}" > /dev/null 2>&1`; then
            ssh jenkins@${i} 'echo "$(facter ipaddress_eth0) $(/bin/hostname)" | sudo tee -a /etc/hosts'
            echo "Successfully copied public keys to slave ${i}"
            break
        elif [ $j -eq $RETRIES ]; then
            echo "SSH not responding on ${i} after $RETIRES tries. Giving up."
            exit 1
        else
            echo "SSH not responding on ${i}. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}

# Print the Stack outputs parameters so that we can identify which IPs belong
# to which VM types.
openstack --os-cloud rackspace stack show -c outputs $STACK_NAME

ADDR=(`openstack --os-cloud rackspace stack show -f json -c outputs $STACK_NAME | \
       jq -r '.outputs[] | \
              select(.output_key | match("^vm_[0-9]+_ips\$")) | \
              .output_value | .[]'`)
pids=""
for i in "${ADDR[@]}"; do
    ( copy-ssh-keys-to-slave ) &
    # Store PID of process
    pids+=" $!"
done

# Detect when a process failed to copy ssh keys and fail build
for p in $pids; do
    if wait $p; then
        echo "Process $p successfully copied ssh keys."
    else
        echo "Process $p failed to copy ssh keys."
        exit 1
    fi
done
echo "Copying ssh keys complete."
