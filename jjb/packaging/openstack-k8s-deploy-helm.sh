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
echo "---> Deploy Opendaylight Helm charts on K8S cluster and verify deployment"
set -eux -o pipefail

set -x

# shellcheck disable=SC1090
. ~/lf-env.sh

K8S_DEPLOY_LOG="$WORKSPACE/archives/k8s-kubectl-file.log"
mkdir -p "$WORKSPACE/archives"

KUBECONFIG="${WORKSPACE}/config"
export KUBECONFIG

# Deploy helm charts after dry run.
cd "$WORKSPACE/helm"
echo "INFO: ODL Helm Charts install --dry-run"
helm3.7 install sdnc opendaylight --dry-run
echo "INFO: ODL Helm Charts install"
helm3.7 install sdnc opendaylight

POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=opendaylight,app.kubernetes.io/instance=sdnc" -o jsonpath="{.items[0].metadata.name}")
CONTAINER_PORT=$(kubectl get pod --namespace default "$POD_NAME" -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
echo "Visit http://127.0.0.1:8080 to use your application"

export POD_NAME
export CONTAINER_PORT

# wait for the pod to become ready
for i in $(seq 10); do
    sleep 50
    # Verify K8S pods are running state before starting port forwarding
    echo "DEBUG: Verify ${KUBECONFIG} is valid and nodes are accessable through kubectl:"
    kubectl describe nodes | tee -a "${K8S_DEPLOY_LOG}"
    kubectl get po -A -o wide | tee -a "${K8S_DEPLOY_LOG}"
    # kubectl get events --sort-by='.metadata.creationTimestamp'
    kubectl get nodes --show-labels

    pod_status=$(kubectl get pods -n default -o jsonpath="{.items[0].status.phase}")
    if [[ "$pod_status" =~ .*Running.* ]]; then
        echo "INFO: SNDC runing on the pod"
        kubectl --namespace default port-forward "$POD_NAME" 8080:"$CONTAINER_PORT" &
        sleep 30
        break
    elif [[ "$pod_status" =~ .*Pending.* ]]; then
        echo "INFO: SNDC pod status: ${pod_status}, creation in progress ..."
        continue
    else
        echo "ERROR: Error in deploying pod"
        kubectl describe pods | tee -a "${K8S_DEPLOY_LOG}"
    fi
    kubectl get pods -n default -o wide
done

# Test SDNC setup by listing restconf modules
SDNC_URL="http://127.0.0.1:8080/restconf/modules"
resp=$(curl -u admin:admin -w "\\n\\n%{http_code}" --globoff -H "Content-Type:application/json" "$SDNC_URL")
json_data=$(echo "$resp" | head -n1)
status=$(echo "$resp" | awk 'END {print $NF}')

if [ "$status" != 200 ]; then
    >&2 echo "ERROR: Failed to fetch data from $SDNC_URL with status code $status"
    >&2 echo "$resp"
    exit 1
else
    echo "INFO: Successfully deploy Opendaylight SND on K8S pod:"
    echo "${json_data}" | jq
fi
