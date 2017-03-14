#!/bin/bash
virtualenv "$WORKSPACE/.venv"
# shellcheck disable=SC1090
source "$WORKSPACE/.venv/bin/activate"
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
