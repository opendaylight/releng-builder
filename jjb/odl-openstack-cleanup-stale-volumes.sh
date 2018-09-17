#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Scans OpenStack for orphaned volumes

mapfile -t os_volumes < <(openstack volume list -f value -c ID --status Available)

echo "---> Orphaned volumes"
if [ ${#os_volumes[@]} -eq 0 ]; then
    echo "No orphaned volumes found."
else
    for volume in "${os_volumes[@]}"; do
        echo "Removing volume $volume"
        lftools openstack --os-cloud vex volume remove --minutes 15 "$volume"
    done
fi
