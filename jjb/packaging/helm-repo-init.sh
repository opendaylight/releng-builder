#!/bin/sh
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Ensure we fail the job if any steps fail
set -e -o pipefail

mkdir -p ".chartstorage"

chartmuseum --port=6464 --storage="local" --storage-local-rootdir=".chartstorage" >/dev/null 2>&1 &
. helm.prop
$HELM_BIN plugin install --version v0.9.0 https://github.com/chartmuseum/helm-push.git || true
$HELM_BIN repo add local http://localhost:6464
$HELM_BIN repo add opendaylight http://localhost:6464
