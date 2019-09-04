#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2019 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Auto-update packer images:
# 1. Get a list of images from the releng/builder repository
# 2. Search openstack cloud for the latest images available
# 3. Compare the time stamps of the new image with the image in use
# 4. Update the image to the config files and yaml files
# 5. Push the change to Gerrit

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade --quiet "pip<10.0.0" setuptools
pip install --upgrade --quiet python-openstackclient
pip freeze

mkdir -p "$WORKSPACE/archives"
echo "List of images used on the source repository:"
egrep -r '(_system_image:|IMAGE_NAME)' | egrep  ZZCI | awk -F: -e '{print $3}' | egrep '\S' | tr -d \'\" | sort -n | uniq | tee "$WORKSPACE/archives/used_image_list.txt"

cat "$WORKSPACE/archives/used_image_list.txt" | while read -r line ; do
    # remove leading white spaces if they exists
    image_in_use="${line#"${line%%[![:space:]]*}"}"
    # remove trailing white spaces if they exists
    image_in_use="${image_in_use%"${image_in_use##*[![:space:]]}"}"
    # images_in_use=$(echo "${line//[\'\"\`]/}")
    # get image type - ex: builder, docker, gbp etc
    image_type="${line% -*}"
    # get the latest image available on the cloud
    new_image=$(openstack image list --long -f value -c Name -c Protected \
        | grep "${image_type}.*False" | tail -n-1 | sed 's/ False//')
    [ -n ${new_image} ] && continue
    # strip the timestamp from the image name amd compare
    new_image_isotime=${new_image##*- }
    image_in_use_isotime=${image_in_use##*- }
    # compare timestamps
    if [ ${new_image_isotime//[\-\.]/} -gt ${image_in_use_isotime//[\-\.]/} ]; then
        # generate a patch to be submited to Gerrit
        echo "Update old image: ${image_in_use} with new image: ${new_image}"
        egrep -rl '(_system_image:|IMAGE_NAME)' | xargs sed -i "s/${image_in_use}/${new_image}/"
    else
        echo "No new image to update: ${new_image}"
    fi
done

git remote -v
git add -u
git status
