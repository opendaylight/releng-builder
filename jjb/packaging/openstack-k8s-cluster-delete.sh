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
echo "---> Delete K8S cluster"

set -eux -o pipefail
# shellcheck disable=SC1090
. ~/lf-env.sh

os_cloud="${OS_CLOUD:-vex}"
cluster_name="${CLUSTER_NAME}"

cluster_delete_status="$(openstack --os-cloud "$OS_CLOUD" coe cluster delete "${CLUSTER_NAME}")"
if [[ -z "$cluster_delete_status" ]]; then
    echo "ERROR: Failed to delete coe cluster ${cluster_name}"
    exit 1
elif [[ "${cluster_delete_status}" =~ .*accepted.* ]]; then
    echo "Cluster ${CLUSTER_NAME} delete in progress ..."
    echo "${cluster_delete_status}"
fi
