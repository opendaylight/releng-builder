#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2021 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# shellcheck disable=SC2153,SC2034
echo "---> Export K8S cluster config and view nodes"
set -eux -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

OS_TIMEOUT=5             # Wait time in minutes for OpenStack cluster nodes to come up.
CLUSTER_NODE_RETRIES=15  # Number of times to retry waiting for a cluster nodes.
CLUSTER_NODE_SUCCESSFUL=false

os_cloud="${OS_CLOUD:-vex}"
cluster_name="${CLUSTER_NAME}"
node_count="${NODE_COUNT:-2}"

echo "INFO: Wait for the ${CLUSTER_NODE_RETRIES} nodes to come up ...."
for try in $(seq $CLUSTER_NODE_RETRIES); do
    sleep 30
    mapfile -t OS_NODES < <(openstack --os-cloud "$os_cloud" server list -f value -c "Name" | grep -E ".*k8s.*")
    if (( ${#OS_NODES[@]} == $((node_count+1)) )); then
        break
    fi
done

echo "INFO: Wait until K8S Cluster nodes are active."
for node in "${OS_NODES[@]}"; do
    echo "node: $node"
    # Get the main node name
    if [[ "$node" =~ .*k8s.*master.* ]]; then
        MAIN_NODE="${node}"
    elif [[ "$node" =~ .*k8s.*node.* ]]; then
        K8S_NODE="${node}"
    else
        echo "ERROR: K8S nodes not online."
        exit 1
    fi
done

# Get Internal IP of master and update ${KUBECONFIG}
if [[ -n "${MAIN_NODE}" ]]; then
    # Add a network for allowing Jenkins node to connect with the K8S nodes
    JOB_SUM=$(echo "$JOB_NAME" | sum | awk '{ print $1 }')
    VM_NAME="$JOB_NAME-$BUILD_NUMBER"
    SERVER_ID="$(openstack --os-cloud vex server show -f value -c id "$(hostname -s)")"
    NETWORK_ID="$(openstack --os-cloud vex network show -f value -c id "$SILO-$VM_NAME")"
    openstack --os-cloud vex server add network "$SERVER_ID" "$NETWORK_ID"

    FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
    FACTER_OSVER=$(/usr/bin/facter operatingsystemrelease)
    if [ "$FACTER_OS" == "centos" ]; then
        ETH1_MAC=$(ip address show eth1 | grep ether | awk -F' ' '{print $2}')
        ETH1_SCRIPT="/etc/sysconfig/network-scripts/ifcfg-eth1"
        sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 "$ETH1_SCRIPT"
        sudo sed -i "s/eth0/eth1/; s/^HWADDR=.*/HWADDR=$ETH1_MAC/" "$ETH1_SCRIPT"
        sudo echo 'PEERDNS=no' | sudo tee -a "$ETH1_SCRIPT"
        sudo echo 'DEFROUTE=no' | sudo tee -a "$ETH1_SCRIPT"
        cat "$ETH1_SCRIPT"
        sudo ifup eth1

    elif [ "$FACTER_OS" == "ubuntu" ]; then
        case "$FACTER_OSVER" in
            18.04)
                ENS3_MAC=$(ip address show ens3 | grep ether | awk -F' ' '{print $2}')
                ENS7_MAC=$(ip address show ens7 | grep ether | awk -F' ' '{print $2}')
                ENS3_SCRIPT="/etc/netplan/50-cloud-init.yaml"
                ENS7_SCRIPT="/etc/netplan/51-cloud-init.yaml"
                sudo cp "$ENS3_SCRIPT" "$ENS7_SCRIPT"
                sudo sed -i "s/ens3/ens7/; s/macaddress: $ENS3_MAC/macaddress: $ENS7_MAC/" "$ENS7_SCRIPT"
                sudo sed -i "s/dhcp: true/d" "$ENS7_SCRIPT"
                cat "$ENS7_SCRIPT"
                sudo netplan apply
            ;;
            *)
                echo "---> Unknown Ubuntu version $FACTER_OSVER"
                exit 1
            ;;
        esac
    else
        echo "---> Unknown OS $FACTER_OS"
        exit 1
    fi

    # print network interfaces
    ip address show

    # Get internal IP of main node
    MAIN_IP=$(openstack --os-cloud "${os_cloud}" server list -f value -c Networks -c Name --name "${SILO}-.*k8s.*-master" | awk -F"'" '{print $4}')

    # Get internal IP of worker node in the cluster
    mapfile -t NODE_IPS < <(openstack --os-cloud "${os_cloud}" server list -f value -c Networks -c Name --name "${SILO}-.*k8s.*-node" | awk -F"'" '{print $4}')
    if (( ${#NODE_IPS[@]} != $((node_count)) )); then
        echo "ERROR: Cluster nodes disappered."
        exit 1
    fi

    echo "INFO: Testing Connectivity between the main and Jenkins minon"
    ping -c3 "$MAIN_IP"
    echo "INFO: Testing Connectivity between the nodes and Jenkins minon"
    for nip in "${NODE_IPS[@]}"; do
        if [[ -n "${nip}" ]]; then
            echo "Ping Node IP Address: $nip"
            ping -c3 "${nip}"
        fi
    done
else
    echo "ERROR: Main node did not come up."
    exit 1
fi

# Export cluster config.
openstack --os-cloud "$os_cloud" coe cluster config "${cluster_name}"
KUBECONFIG="${WORKSPACE}/config"
export KUBECONFIG

# Update main node IP in KUBECONFIG
if [[ -n ${MAIN_IP} ]]; then
    sed -i "s#server:.*#server: https://${MAIN_IP}:6443#" "$KUBECONFIG"
    cat "${KUBECONFIG}"
fi

# Print helm and kubectl version
echo "INFO: helm version:"
helm3.7 version
echo "INFO: kubectl version:"
kubectl version
