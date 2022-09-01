#!/bin/sh -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# shellcheck disable=SC2039
set -e -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 python-openstackclient

cat > "$WORKSPACE/docs/cloud-images.rst" << EOF
Following are the list of published images available to Jenkins jobs.

EOF
# Blank line before EOF is on purpose to ensure there is spacing.

IFS='
'
# We purposely want globbing here to build images list
# shellcheck disable=SC2207
IMAGES="$(openstack image list --long -f value -c Name -c Protected \
    | grep 'ZZCI.*True' | sed 's/ True//')"
for i in $IMAGES; do
    echo "Adding image $i"
    echo "* $i" >> "$WORKSPACE/docs/cloud-images.rst"
done

git add docs/cloud-images.rst
