#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> Cleanup orphaned volumes"

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient

volumes=($(openstack volume list -f value -c ID -c Status \
    | grep available | awk '{print $1}'))

for vol in ${volumes[@]}; do
    echo "Deleting volume $i"
    openstack --os-cloud odl volume delete "$vol"
    # Wait to give Vexxhost some time to delete the volume
    sleep 5
done
