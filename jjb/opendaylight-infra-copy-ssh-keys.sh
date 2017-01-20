#!/bin/bash
function copy-ssh-keys-to-slave() {
    RETRIES=60
    for j in $(seq 1 $RETRIES); do
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

source $WORKSPACE/.venv-openstack/bin/activate
CONTROLLER_IPS=`openstack --os-cloud rackspace stack show -f json -c outputs $STACK_NAME | jq -r '.outputs[] | select(.output_key=="vm_0_ips") | .output_value[]'`
MININET_IPS=`openstack --os-cloud rackspace stack show -f json -c outputs $STACK_NAME | jq -r '.outputs[] | select(.output_key=="vm_1_ips") | .output_value[]'`
ADDR=($CONTROLLER_IPS $MININET_IPS)

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
