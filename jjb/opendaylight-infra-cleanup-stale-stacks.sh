#!/bin/bash
virtualenv $WORKSPACE/.venv
source $WORKSPACE/.venv/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

DELETE_LIST=(`openstack --os-cloud rackspace stack list -f json | \
              jq -r '.[] | \
                     select((."Stack Status" == "CREATE_FAILED") or \
                            (."Stack Status" == "DELETE_FAILED")) | \
                     ."Stack Name"'`)
for i in "${DELETE_LIST[@]}"; do
    echo "Deleting stack $i"
    openstack --os-cloud rackspace stack delete --yes $i
done
