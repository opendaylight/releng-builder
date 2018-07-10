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

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade --quiet "pip<10.0.0" setuptools
pip install --upgrade --quiet python-openstackclient
pip freeze

df -h

cd /builder/openstack-hot || exit 1
mkdir -p /tmp/apex_snapshots
pushd /tmp/apex_snapshots

wget --progress=dot:giga http://artifacts.opnfv.org/apex/apex-csit-snap-2018-07-08.tar.gz
gunzip apex-csit-snap-2018-07-08.tar.gz

# builder VMs don't have enough disk to handle a full un-tarring, so doing one
# big file at a time and deleting it from the tarball as a workaround for now
tar -tf apex-csit-snap-2018-07-08.tar
tar -xf apex-csit-snap-2018-07-08.tar ./baremetal0.qcow2
tar --delete --file=apex-csit-snap-2018-07-08.tar ./baremetal0.qcow2
tar -xf apex-csit-snap-2018-07-08.tar ./baremetal1.qcow2
tar --delete --file=apex-csit-snap-2018-07-08.tar ./baremetal1.qcow2
tar -xf apex-csit-snap-2018-07-08.tar ./baremetal2.qcow2
tar --delete --file=apex-csit-snap-2018-07-08.tar ./baremetal2.qcow2
tar -tf apex-csit-snap-2018-07-08.tar
tar -xvf apex-csit-snap-2018-07-08.tar
ls -altr

# grab the right baremetal# for the controller(s) and compute(s)
CONTROLLER_NODE=$(egrep 'type|vNode-name' node.yaml | egrep -A1 controller | tail -n1 | awk '{print $2}')
COMPUTE_0_NODE=$(egrep 'type|vNode-name' node.yaml | egrep -A1 compute | tail -n1 | awk '{print $2}')
COMPUTE_1_NODE=$(egrep 'type|vNode-name' node.yaml | egrep -A1 compute | head -n2 | tail -n1 | awk '{print $2}')

popd

openstack image list

sudo yum install -y qemu-img

qemu-img convert -f qcow2 -O raw /tmp/apex_snapshots/$CONTROLLER_NODE.qcow2 /tmp/apex_snapshots/$CONTROLLER_NODE.raw
rm /tmp/apex_snapshots/$CONTROLLER_NODE.qcow2
openstack image create \
  --disk-format raw --container-format bare \
  --file /tmp/apex_snapshots/$CONTROLLER_NODE.raw "OPNFV - apex - controller - 0"

qemu-img convert -f qcow2 -O raw /tmp/apex_snapshots/$COMPUTE_0_NODE.qcow2 /tmp/apex_snapshots/$COMPUTE_0_NODE.raw
rm /tmp/apex_snapshots/$COMPUTE_0_NODE.qcow2
openstack image create \
  --disk-format raw --container-format bare \
  --file /tmp/apex_snapshots/$COMPUTE_0_NODE.raw "OPNFV - apex - compute - 0"

qemu-img convert -f qcow2 -O raw /tmp/apex_snapshots/$COMPUTE_1_NODE.qcow2 /tmp/apex_snapshots/$COMPUTE_1_NODE.raw
rm /tmp/apex_snapshots/$COMPUTE_1_NODE.qcow2
openstack image create \
  --disk-format raw --container-format bare \
  --file /tmp/apex_snapshots/$COMPUTE_1_NODE.raw "OPNFV - apex - compute - 1"

openstack image list

df -h

