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

CHANGE_ID=`ssh -p 29418 jenkins-$SILO@git.opendaylight.org gerrit query \
               limit:1 owner:self is:open project:releng/builder \
               topic:update-cloud-image-list | \
               grep 'Change-Id:' | \
               awk '{ print $2 }'`
git add docs/cloud-images.rst

if [ -z "$CHANGE_ID" ]; then
    git commit -sm "Update cloud-images"
else
    git commit -sm "Update cloud-images" -m "Change-Id: $CHANGE_ID"
fi

git status
git remote add gerrit ssh://jenkins-$SILO@git.opendaylight.org:29418/releng/builder.git
git review --yes -t update-cloud-image-list
