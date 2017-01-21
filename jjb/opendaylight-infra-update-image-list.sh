#!/bin/bash
virtualenv $WORKSPACE/.venv
source $WORKSPACE/.venv/bin/activate
pip install --upgrade --quiet pip
pip install --upgrade --quiet python-openstackclient python-heatclient
pip freeze

cat > $WORKSPACE/docs/cloud-images.rst << EOF
Cloud Images
============
EOF

IFS=$'\n'
IMAGES=(`openstack --os-cloud rackspace image list --public -f value -c Name`)
for i in ${IMAGES[@]}; do
    echo "* $i" >> $WORKSPACE/docs/cloud-images.rst
done

git add docs/cloud-images.rst
