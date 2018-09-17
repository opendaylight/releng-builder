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
# Checks the image "protected" value and set "True" marker
#
# The script is involked by 'builder-verify-image-protection', searches
# the jjb source code for the images presently used and verifies protection
# setting. If the image protect setting is not "True", sets the
# image protect setting to "True" to prevent the image from getting purged
# by the cleanup old images job.
echo "---> Check image protection"

declare -a yaml_images
readarray -t yaml_images <<< "$(grep -r _system_image: --include \*.yaml \
    | awk -F": " -e '{print $3}' | sed "s:'::;s:'$::;/^$/d" | sort -u)"
declare -a cfg_images
readarray -t cfg_images <<< "$(grep -r IMAGE_NAME --include \*.cfg \
    | awk -F'=' -e '{print $2}' | sort -u)"
combined=("${yaml_images[@]}" "${cfg_images[@]}")
declare -a images
readarray -t images <<< "$(printf '%s\n' "${combined[@]}" | sort -u)"

for image in "${images[@]}"; do
    os_image_protected=$(openstack --os-cloud "$OS_CLOUD" image show "$image" -f value -c protected)
    echo "Protected setting for $image: $os_image_protected"
    if [[ $os_image_protected != True ]]; then
        echo "Image: $image NOT set as protected, changing the protected value."
        openstack --os-cloud "$OS_CLOUD" image set --protected "$image"
    fi
done
