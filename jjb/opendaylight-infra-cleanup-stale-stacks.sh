#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip install --upgrade pipdeptree
pipdeptree

#########################
## FETCH ACTIVE BUILDS ##
#########################
# Fetch stack list before fetching active builds to minimize race condition
# where we might be try to delete stacks while jobs are trying to start
OS_STACKS=($(openstack stack list \
            -f value -c "Stack Name" -c "Stack Status" \
            --property "stack_status=CREATE_COMPLETE" \
            --property "stack_status=DELETE_FAILED" \
            --property "stack_status=CREATE_FAILED" \
            | awk '{print $1}'))

# Make sure we fetch active builds on both the releng and sandbox silos
ACTIVE_BUILDS=()
for silo in releng sandbox; do
    JENKINS_URL="https://jenkins.opendaylight.org/$silo//computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds"
    wget -nv -O "${silo}_builds.json" "$JENKINS_URL"
    sleep 1  # Need to sleep for 1 second otherwise next line causes script to stall
    ACTIVE_BUILDS=(${ACTIVE_BUILDS[@]} $( \
        jq -r '.computer[].executors[].currentExecutable.url' "${silo}_builds.json" \
        | grep -v null | awk -F'/' '{print $4 "-" $6 "-" $7}'))
done

##########################
## DELETE UNUSED STACKS ##
##########################
# Search for stacks that are not in use by either releng or sandbox silos and
# delete them.
for STACK_NAME in "${OS_STACKS[@]}"; do
    echo "Deleting stack $STACK_NAME"
    STACK_STATUS=$(openstack stack show -f value -c "stack_status" "$STACK_NAME")
    if [[ "${ACTIVE_BUILDS[*]}" =~ $STACK_NAME ]]; then
        # No need to delete stacks if there exists an active build for them
        continue
    else
        case "$STACK_STATUS" in
            DELETE_IN_PROGRESS)
                echo "skipping delete, $STACK_NAME is already DELETE in progress."
                continue
            ;;
            DELETE_FAILED)
                # Abandon is not supported in Vexxhost so let's keep trying to
                # delete for now...
                # echo "Stack delete failed, trying to stack abandon now."
                # openstack stack abandon "$STACK_NAME"
                echo "Deleting orphaned stack: $STACK_NAME"
                openstack stack delete --yes "$STACK_NAME"
                STACK_SHOW=$(openstack stack show "$STACK_NAME")
                echo "$STACK_SHOW"
                continue
            ;;
            CREATE_COMPLETE|CREATE_FAILED)
                echo "Deleting orphaned stack: $STACK_NAME"
                openstack stack delete --yes "$STACK_NAME"
                continue
            ;;
            *)
                continue
            ;;
        esac
    fi
done
