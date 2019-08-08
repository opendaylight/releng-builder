#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 Red Hat, Inc. and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Ensure we fail the job if any steps fail.
set -x -o pipefail -o errexit

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade --quiet "pip<10.0.0" setuptools
pip install --upgrade --quiet python-openstackclient
pip freeze

df -h

mkdir -p /tmp/apex_snapshots
pushd /tmp/apex_snapshots

wget artifacts.opnfv.org/apex/queens/noha/snapshot.properties
cat snapshot.properties
# shellcheck disable=SC1091
source snapshot.properties
SNAPSHOT_FILENAME=$(basename "$OPNFV_SNAP_URL")

wget --progress=dot:giga "$OPNFV_SNAP_URL"
gunzip -c "$SNAPSHOT_FILENAME" > snapshots.tar

# builder VMs don't have enough disk to handle a full un-tarring, so doing one
# big file at a time and deleting it from the tarball as a workaround for now
tar -tf snapshots.tar

images=$(tar --list -f snapshots.tar | grep qcow2)
for image in $images; do
  tar -xf snapshots.tar "$image"
  tar --delete --file=snapshots.tar "$image"
done

# get the ssh keys and node.yaml for uploading to swift at the end
tar -xf snapshots.tar ./id_rsa
tar -xf snapshots.tar ./node.yaml
tar -xf snapshots.tar ./overcloudrc

ls -altr

# grab the right baremetal# for the controller(s) and compute(s)
CONTROLLER_NODE=$(grep -E 'type|vNode-name' node.yaml | grep -E -A1 controller | tail -n1 | awk '{print $2}')
COMPUTE_0_NODE=$(grep -E 'type|vNode-name' node.yaml | grep -E -A1 compute | tail -n1 | awk '{print $2}')
COMPUTE_1_NODE=$(grep -E 'type|vNode-name' node.yaml | grep -E -A1 compute | head -n2 | tail -n1 | awk '{print $2}')

# Customize images to work in ODL Vexxhost infra
sudo yum install -y libguestfs-tools
export LIBGUESTFS_BACKEND=direct
virt-customize -a "$CONTROLLER_NODE.qcow2" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini ml2 physical_network_mtus datacentre:1458" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini ml2 path_mtu 1458" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf '' global_physnet_mtu 1458" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/dhcp_agent.ini '' debug true" \

virt-customize -a "$COMPUTE_0_NODE.qcow2" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf libvirt virt_type qemu"

virt-customize -a "$COMPUTE_1_NODE.qcow2" \
  --run-command "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf libvirt virt_type qemu"

for image in $CONTROLLER_NODE $COMPUTE_0_NODE $COMPUTE_1_NODE
do
  # Change interface MTU to account for default network mtu of 1458
  virt-customize -a "$image.qcow2" \
    --run-command 'sudo echo "MTU=\"1458\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0' \
    --run-command 'sudo echo "MTU=\"1458\"" >> /etc/sysconfig/network-scripts/ifcfg-br-int' \
    --run-command 'sudo echo "MTU=\"1458\"" >> /etc/sysconfig/network-scripts/ifcfg-ovs-system' \
    --run-command "sudo crudini --set /etc/selinux/config '' SELINUX permissive"
done

popd

openstack image list

# clean out any zombie OPNFV - apex images that *may* be left over from troubled jobs
openstack image list | grep -E 'OPNFV - apex.*new ' | awk '{print "openstack image delete",$2}' | sh || true

qemu-img convert -f qcow2 -O raw "/tmp/apex_snapshots/$CONTROLLER_NODE.qcow2" "/tmp/apex_snapshots/$CONTROLLER_NODE.raw"
rm "/tmp/apex_snapshots/$CONTROLLER_NODE.qcow2"
qemu-img convert -f qcow2 -O raw "/tmp/apex_snapshots/$COMPUTE_0_NODE.qcow2" "/tmp/apex_snapshots/$COMPUTE_0_NODE.raw"
rm "/tmp/apex_snapshots/$COMPUTE_0_NODE.qcow2"
qemu-img convert -f qcow2 -O raw "/tmp/apex_snapshots/$COMPUTE_1_NODE.qcow2" "/tmp/apex_snapshots/$COMPUTE_1_NODE.raw"
rm "/tmp/apex_snapshots/$COMPUTE_1_NODE.qcow2"

# create .new images first, then we can delete the existing and rename .new
# to existing to reduce the delta of when these images might be unavailable
CONTROLLER_IMAGE_NAME="ZZCI - OPNFV - apex - controller - 0"
COMPUTE_0_IMAGE_NAME="ZZCI - OPNFV - apex - compute - 0"
COMPUTE_1_IMAGE_NAME="ZZCI - OPNFV - apex - compute - 1"

openstack image create \
  --disk-format raw --container-format bare \
  --file "/tmp/apex_snapshots/$CONTROLLER_NODE.raw" "$CONTROLLER_IMAGE_NAME.new"
openstack image create \
  --disk-format raw --container-format bare \
  --file "/tmp/apex_snapshots/$COMPUTE_0_NODE.raw" "$COMPUTE_0_IMAGE_NAME.new"
openstack image create \
  --disk-format raw --container-format bare \
  --file "/tmp/apex_snapshots/$COMPUTE_1_NODE.raw" "$COMPUTE_1_IMAGE_NAME.new"

# clean out any non ".new" OPNFV - apex images. In the case of a previously failed
# or aborted apex management job, we can end up with multiple images with the same
# name so being thorough here.
openstack image list | grep -E 'OPNFV - apex' | grep -Ev 'new' | awk '{print "openstack image delete",$2}' | sh

openstack image set --name "$CONTROLLER_IMAGE_NAME" "$CONTROLLER_IMAGE_NAME.new"
openstack image set --tag "Date Uploaded: $(date)" "$CONTROLLER_IMAGE_NAME"
openstack image set --tag "Apex Archive: $(basename "$OPNFV_SNAP_URL")" "$CONTROLLER_IMAGE_NAME"

openstack image set --name "$COMPUTE_0_IMAGE_NAME" "$COMPUTE_0_IMAGE_NAME.new"
openstack image set --tag "Date Uploaded: $(date)" "$COMPUTE_0_IMAGE_NAME"
openstack image set --tag "Apex Archive: $(basename "$OPNFV_SNAP_URL")" "$COMPUTE_0_IMAGE_NAME"

openstack image set --name "$COMPUTE_1_IMAGE_NAME" "$COMPUTE_1_IMAGE_NAME.new"
openstack image set --tag "Date Uploaded: $(date)" "$COMPUTE_1_IMAGE_NAME"
openstack image set --tag "Apex Archive: $(basename "$OPNFV_SNAP_URL")" "$COMPUTE_1_IMAGE_NAME"

# Now that the images should be up, active and ready, we can update
# the ssh key and node.yaml in swift
openstack container create OPNFV-APEX-SNAPSHOTS
openstack object create OPNFV-APEX-SNAPSHOTS /tmp/apex_snapshots/node.yaml --name node.yaml
openstack object create OPNFV-APEX-SNAPSHOTS /tmp/apex_snapshots/id_rsa --name id_rsa
openstack object create OPNFV-APEX-SNAPSHOTS /tmp/apex_snapshots/overcloudrc --name overcloudrc
openstack object list OPNFV-APEX-SNAPSHOTS

openstack image list

df -h

