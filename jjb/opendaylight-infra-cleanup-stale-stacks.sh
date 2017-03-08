#!/bin/bash
virtualenv "$WORKSPACE/.venv"
# shellcheck disable=SC1090
source "$WORKSPACE/.venv/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

#########################
## FETCH ACTIVE BUILDS ##
#########################
# Fetch stack list before fetching active builds to minimize race condition
# where we might be try to delete stacks while jobs are trying to start
OS_STACKS=$(openstack --os-cloud rackspace stack list \
            -f json -c "Stack Name" -c "Stack Status" \
            --property "stack_status=CREATE_COMPLETE" \
            --property "stack_status=DELETE_FAILED" \
            --property "stack_status=CREATE_FAILED" \
            | jq -r '.[] | ."Stack Name"')

# Make sure we fetch active builds on both the releng and sandbox silos
ACTIVE_BUILDS=()
for silo in releng sandbox; do
    JENKINS_URL="https://jenkins.opendaylight.org/$silo//computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds"
    wget --no-verbose -O "${silo}_builds.json" "$JENKINS_URL"
    sleep 1  # Need to sleep for 1 second otherwise next line causes script to stall
    ACTIVE_BUILDS=(${ACTIVE_BUILDS[@]} $( \
        jq -r '.computer[].executors[].currentExecutable.url' "$silo_builds.json" \
        | grep -v null | awk -F'/' '{print $6 "-" $7}'))
done

##########################
## DELETE UNUSED STACKS ##
##########################
# Search for stacks taht are not in use by either releng or sandbox silos and
# delete them.
for stack in "${OS_STACKS[@]}"; do
    if [[ "${ACTIVE_BUILDS[@]}" =~ $stack ]]; then
        # No need to delete stacks if there exists an active build for them
        continue
    else
        echo "Deleting orphaned stack: $stack"
        openstack --os-cloud rackspace stack delete --yes "$stack"
    fi
done
