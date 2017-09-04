#!/bin/bash -x
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015, 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Checks the image visibility and set "public" marker
#
# The script is involked by 'builder-verify-image-visibility', searches
# the jjb source code for the images presently uesd and verifies visibility
# on RS private cloud. If the image visibility is not "public", set the
# image visibility to "public" to prevent the image from getting purged
# by the cleanup old images job.

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient
pip install --upgrade pipdeptree
pipdeptree

declare -a images
readarray -t images <<< "$(grep -r _system_image: --include \*.yaml | awk -F": " -e '{print $3}' | sed "s:'::;s:'$::;/^$/d")"

for image in "${images[@]}"; do
    os_image_visibility=$(openstack --os-cloud $OS_CLOUD image show "$image" -f json -c "visibility" | jq -r '.[]')
    echo "Visibility for $image: $os_image_visibility"
    if [[ $os_image_visibility != public ]]; then
        echo "Image: $image NOT set as public, changing the visibility"
        openstack --os-cloud $OS_CLOUD image set --public "$image"
    fi
done
