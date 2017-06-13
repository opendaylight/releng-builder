#!/bin/bash
virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade --quiet pip
pip install --upgrade --quiet python-openstackclient python-heatclient
pip freeze

cat > "$WORKSPACE/docs/cloud-images.rst" << EOF
Following are the list of published images available to be used with Jenkins jobs.

EOF
# Blank line before EOF is on purpose to ensure there is spacing.

IFS=$'\n'
IMAGES=($(openstack image list --public -f value -c Name))
for i in "${IMAGES[@]}"; do
    echo "* $i" >> "$WORKSPACE/docs/cloud-images.rst"
done

git add docs/cloud-images.rst
