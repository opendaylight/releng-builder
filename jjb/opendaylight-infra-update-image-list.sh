#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

set -e -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 python-openstackclient

cat > "$WORKSPACE/docs/cloud-images.rst" << EOF
Cloud Images
============

Below is the historical list of published images available to Jenkins jobs.
New projects should target the most recent Ubuntu 22.04 (Jammy) images
(builder / docker / devstack / mininet) or CentOS Stream 8 where Ubuntu is not
yet available. We have deprecated CentOS 7 images and plan to remove them
after the final migration (date TBD).

Recommended (current) labels (see Jenkins node labels / job parameters for
exact names):

* Ubuntu 22.04 builder (Java 17 default)
* Ubuntu 22.04 docker
* Ubuntu 22.04 devstack (for OpenStack CSIT)
* Ubuntu 22.04 mininet-ovs-217
* CentOS Stream 8 builder (legacy support / transitional)

Historical inventory:

EOF
# Blank line before EOF is on purpose to ensure there is spacing.

IFS=$'\n'
# We purposely want globbing here to build images list
# shellcheck disable=SC2207
IMAGES=($(openstack image list --long -f value -c Name -c Protected \
    | grep 'ZZCI.*True' | sed 's/ True//'))
for i in "${IMAGES[@]}"; do
    echo "Adding image $i"
    echo "* $i" >> "$WORKSPACE/docs/cloud-images.rst"
done

git add docs/cloud-images.rst
