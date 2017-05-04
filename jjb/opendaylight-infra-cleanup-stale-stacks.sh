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
OS_STACKS=($(openstack stack list \
            -f json -c "Stack Name" -c "Stack Status" -c "ID" \
            --property "stack_status=CREATE_COMPLETE" \
            --property "stack_status=DELETE_FAILED" \
            --property "stack_status=CREATE_FAILED" \
            | jq -r '.[] | ."Stack Name"'))

# Make sure we fetch active builds on both the releng and sandbox silos
ACTIVE_BUILDS=()
for silo in releng sandbox; do
    JENKINS_URL="https://jenkins.opendaylight.org/$silo//computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds"
    wget --no-verbose -O "${silo}_builds.json" "$JENKINS_URL"
    sleep 1  # Need to sleep for 1 second otherwise next line causes script to stall
    ACTIVE_BUILDS=(${ACTIVE_BUILDS[@]} $( \
        jq -r '.computer[].executors[].currentExecutable.url' "${silo}_builds.json" \
        | grep -v null | awk -F'/' '{print $6 "-" $7}'))
done

##########################
## DELETE UNUSED STACKS ##
##########################
# Search for stacks that are not in use by either releng or sandbox silos and
# delete them.
for STACK_NAME in "${OS_STACKS[@]}"; do
    STACK_STATUS=$(openstack stack show -f json -c "stack_status" "$STACK_NAME" | jq -r '."stack_status"')
    if [[ "${ACTIVE_BUILDS[@]}" =~ $STACK_NAME ]]; then
        # No need to delete stacks if there exists an active build for them
        continue
    elif [[ "$STACK_STAUS" ~= "DELETE_FAILED" ]]; then
        echo "Stack delete failed, trying to stack abandon now."
        # stack abandon does not work on RS, therefore requires acquiring a token
        # and using http delete method to abondon DELETE_FAILED stacks
        # Todo: remove the change once RS fixes the issue upstream
        # openstack stack abandon "$STACK_NAME"
        STACK_ID=$(openstack stack show -f json -c "id" "$STACK_NAME" | jq -r '."id"')
        TOKEN=$(openstack token issue -f json -c id | jq -r '.id')
        curl -si -X DELETE -H "Content-Type: application/json" -H "Accept: application/json"\
            -H "x-auth-token: $TOKEN"\
            "https://dfw.orchestration.api.rackspacecloud.com/v1/904885/stacks/$STACK_NAME/$STACK_ID/abandon"
        STACK_SHOW=$(openstack stack show "$STACK_NAME")
        echo "$STACK_SHOW"
    else
        echo "Deleting orphaned stack: $STACK_NAME"
        openstack stack delete --yes "$STACK_NAME"
    fi
done
