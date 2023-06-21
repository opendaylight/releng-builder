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
echo "---> Create K8S cluster with pre-existing template"

set -eux -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 \
    python-heatclient \
    python-openstackclient \
    urllib3~=1.26.15 \
    yq

OS_TIMEOUT=20       # Wait time in minutes for OpenStack cluster to come up.
CLUSTER_RETRIES=3   # Number of times to retry creating a cluster.
CLUSTER_SUCCESSFUL=false

mkdir -p "$WORKSPACE/archives"

boot_volume_size="${BOOT_VOLUME_SIZE}"
cluster_name="${CLUSTER_NAME}"
cluster_settle_time="${CLUSTER_SETTLE_TIME:-1m}"
cluster_template_name="${CLUSTER_TEMPLATE_NAME}"
cloud_provider_tag="${CLOUD_PROVIDER_TAG}"
container_infra_prefix="${CONTAINER_INFRA_PREFIX}"
etcd_volume_size="${ETCD_VOLUME_SIZE}"
k8s_version="${K8S_VERSION}"
keypair="${KEYPAIR}"
kube_tag="${KUBE_TAG}"
helm_client_url="${HELM_CLIENT_URL}"
helm_sha256="${HELM_SHA256}"
helm_version="${HELM_VERSION}"
master_count="${MASTER_COUNT:-1}"
master_flavor="${MASTER_FLAVOR}"
master_lb_floating_ip_enabled="${MASTER_LB_FLOATING_IP_ENABLED:-false}"
node_count="${NODE_COUNT:-2}"
node_flavor="${NODE_FLAVOR}"
os_cloud="${OS_CLOUD:-vex}"

echo "INFO: Create a Cluster:${CLUSTER_NAME} for attempts:${CLUSTER_RETRIES}."
for try in $(seq $CLUSTER_RETRIES); do
    # shellcheck disable=SC1083

    # Create the cluster using pre-defined template. Returns the status which includes the $cluster_uuid
    cluster_status=$(openstack --os-cloud "${os_cloud}" coe cluster create "${cluster_name}" \
        --cluster-template "${cluster_template_name}" \
        --keypair "${keypair}" \
        --master-count "${master_count}" \
        --node-count "${node_count}" \
        --master-flavor "${master_flavor}" \
        --flavor "${node_flavor}" \
        --labels \
boot_volume_size="${boot_volume_size}",\
container_infra_prefix="${container_infra_prefix}",\
cloud_provider_tag="${cloud_provider_tag}",\
helm_client_sha256="${helm_sha256}",\
helm_client_tag="${helm_version}",\
etcd_volume_size="${etcd_volume_size}",\
kube_tag="${kube_tag}",\
master_lb_floating_ip_enabled=false,\
helm_client_url="${helm_client_url}" \
        --floating-ip-disabled)

    # Check return status and extract the $cluster_uuid from return status
    if [[ -z "$cluster_status" ]]; then
        echo "ERROR: Failed to create coe cluster ${cluster_name}"
        exit 1
    elif [[ "${cluster_status}" =~ .*accepted.* ]]; then
        cluster_uuid=$(echo "${cluster_status}" | awk -F' ' '{print $5}')
    fi

    echo "INFO $try: Wait until ${OS_TIMEOUT} (in minutes) to rollout ${cluster_name}."
    for i in $(seq $OS_TIMEOUT); do
        sleep 90

        CLUSTER_STATUS=$(openstack --os-cloud "$os_cloud" coe cluster show "$cluster_uuid" -c status -f value)
        echo "$i: ${CLUSTER_STATUS}"

        case "${CLUSTER_STATUS}" in
            CREATE_COMPLETE)
                echo "INFO: Cluster ${cluster_name} initialized on infrastructure successful."
                CLUSTER_SUCCESSFUL=true
                break
            ;;
            CREATE_FAILED)
                reason=$(openstack coe cluster show "${cluster_name}" -f value -c health_status_reason)
                echo "ERROR: Failed to initialize infrastructure. Reason: ${reason}"
                openstack ceo cluster show "${cluster_name}"

                echo "INFO: Deleting cluster and re-try to create the cluster again ..."
                openstack coe cluster delete "${cluster_name}"

                # Post delete, poll for 5m to learn if cluster is fully removed
                for j in $(seq 20); do
                    sleep 30
                    delete_status=$(openstack coe cluster show "${cluster_name}" -f value -c status)
                    echo "$j: ${delete_status}"
                    if [[ ${delete_status} == "DELETE_FAILED" ]]; then
                        reason=$(openstack coe cluster show "${cluster_name}" -f value -c health_status_reason)
                        echo "ERROR: Failed to delete ${cluster_name}. Reason: ${reason}"

                        echo "INFO: Deleting failed cluster again: ${cluster_name}"
                        openstack coe cluster delete "${cluster_name}"
                    fi

                    if ! openstack coe cluster show "${cluster_name}" -f value -c status; then
                        echo "INFO: Cluster show on ${cluster_name} came back empty. Assuming successful delete"
                        break
                    fi
                done

                # If we still see $CLUSTER_NAME in `openstack coe cluster show` this infers the delete hasn't fully
                # worked and we can exit forcefully
                if openstack coe cluster show "${cluster_name}" -f value -c stack_status; then
                    echo "ERROR: Cluster ${cluster_name} still in cloud output after polling. Quitting!"
                    exit 1
                fi
                break
            ;;
            CREATE_IN_PROGRESS)
                echo "INFO: Waiting to initialize cluster infrastructure ..."
                continue
            ;;
            *)
                echo "ERROR: Unexpected status: ${OS_STATUS}"
                # DO NOT exit on unexpected status. Openstack cluster sometimes returns unexpected status
                # before returning an expected status. Just print the message and loop until we have
                # a confirmed state or timeout.
                # exit 1
            ;;
        esac
    done
    if $CLUSTER_SUCCESSFUL; then
        break
    fi
done
