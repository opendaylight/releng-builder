#!/bin/bash
virtualenv $WORKSPACE/.venv
source $WORKSPACE/.venv/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

#########################
## FETCH ACTIVE BUILDS ##
#########################
# Make sure we fetch active builds on both the releng and sandbox silos
wget -q -O releng_builds.json https://jenkins.opendaylight.org/releng/computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds
sleep 1  # Need to sleep for 1 second otherwise next line causes script to stall
ACTIVE_BUILDS_RELENG=(` \
    jq -r '.computer[].executors[].currentExecutable.url' releng_builds.json \
    | grep -v null | awk -F'/' '{print $6 "-" $7}'`)

wget -q -O sandbox_builds.json https://jenkins.opendaylight.org/sandbox/computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds
sleep 1  # Need to sleep for 1 second otherwise next line causes script to stall
ACTIVE_BUILDS_SANDBOX=(` \
    jq -r '.computer[].executors[].currentExecutable.url' sandbox_builds.json \
    | grep -v null | awk -F'/' '{print $6 "-" $7}'`)

##########################
## DELETE UNUSED STACKS ##
##########################
# Search for stacks taht are not in use by either releng or sandbox silos and
# delete them.
ACTIVE_BUILDS=(${ACTIVE_BUILDS_RELENG[@]} ${ACTIVE_BUILDS_SANDBOX[@]})
OS_STACKS=(`openstack --os-cloud rackspace stack list \
            -f json -c "Stack Name" -c "Stack Status" \
            --property "stack_status=CREATE_COMPLETE" \
            --property "stack_status=DELETE_FAILED" \
            --property "stack_status=CREATE_FAILED" \
            | jq -r '.[] | ."Stack Name"'`)
for stack in ${OS_STACKS[@]}; do
    if [[ "${ACTIVE_BUILDS[@]}" =~ $stack ]]; then
        # No need to delete stacks if there exists an active build for them
        continue
    else
        echo "Deleting orphaned stack: $stack"
        openstack --os-cloud rackspace stack delete --yes $stack
    fi
done
