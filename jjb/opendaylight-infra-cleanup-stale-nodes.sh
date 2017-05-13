#!/bin/bash
virtualenv "$WORKSPACE/.venv"
# shellcheck disable=SC1090
source "$WORKSPACE/.venv/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

# Get list of all nodes on RS
OS_NODES=()
OS_NODES=($(openstack server list \
                      -f json -c "Name" -c "ID" -c "Status" \
                      | jq -r '.[] | ."ID"'))

# All jobs are expected to complete within 24H atmost, therefore we can have a job
# which cleans up nodes on RS by checking the creation time of the node, if the
# node creation time is older than 24H then delete that node from RS.
for node in "${OS_NODES[@]}"; do
    NODE_CREATE_TIME=$(openstack server show \
                                -f json -c "created" -c "id" -c "name" \
                                "$node" \
                                | jq -r '."created"')
    NODE_CREATE_EPOCH=$(date -d "${NODE_CREATE_TIME}" +%s)
    BEFORE=$(date -d "-1 day" +%s)
    NOW=$(date -d "now" +%s)
    if [[ -z "$NODE_CREATE_EPOCH" || "$NODE_CREATE_EPOCH" > "$BEFORE" ]]; then
        continue
    else
        echo "$node creation time is $NODE_CREATE_TIME, delete node"
        openstack server delete $node --wait
    fi
done
