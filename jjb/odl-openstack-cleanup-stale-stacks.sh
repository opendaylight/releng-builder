#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Cleanup stale stacks in the cloud
# Requires the variable JENKINS_URLS declared in the job as a space separated
# list of Jenkins instances to check for active builds.
echo "---> Cleanup stale stacks"

stack_in_jenkins() {
    # Usage: check_stack_in_jenkins STACK_NAME JENKINS_URL [JENKINS_URL...]
    # Returns: 0 If stack is in Jenkins and 1 if stack is not in Jenkins.

    STACK_NAME="${1}"

    builds=()
    for jenkins in "${@:2}"; do
        JENKINS_URL="$jenkins/computer/api/json?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds"
        resp=$(curl -s -w "\\n\\n%{http_code}" --globoff -H "Content-Type:application/json" "$JENKINS_URL")
        json_data=$(echo "$resp" | head -n1)
        #status=$(echo "$resp" | awk 'END {print $NF}')

        if [[ "${jenkins}" == *"jenkins."*".org" ]]; then
            silo="production"
        else
            silo=$(echo "$jenkins" | sed 's/\/*$//' | awk -F'/' '{print $NF}')
        fi
        export silo
        # We purposely want to wordsplit here to combine the arrays
        # shellcheck disable=SC2206,SC2207
        builds=(${builds[@]} $(echo "$json_data" | \
            jq -r '.computer[].executors[].currentExecutable.url' \
            | grep -v null | awk -F'/' '{print ENVIRON["silo"] "-" $6 "-" $7}')
        )
    done

    if [[ "${builds[*]}" =~ $STACK_NAME ]]; then
        return 0
    fi

    return 1
}

#########################
## FETCH ACTIVE BUILDS ##
#########################
# Fetch stack list before fetching active builds to minimize race condition
# where we might be try to delete stacks while jobs are trying to start

# We purposely need word splitting here to create the OS_STACKS array.
# shellcheck disable=SC2207
OS_STACKS=($(openstack stack list \
            -f value -c "Stack Name" -c "Stack Status" \
            --property "stack_status=CREATE_COMPLETE" \
            --property "stack_status=DELETE_FAILED" \
            --property "stack_status=CREATE_FAILED" \
            | awk '{print $1}'))

echo "---> Active stacks"
for stack in "${OS_STACKS[@]}"; do
    echo "$stack"
done

##########################
## DELETE UNUSED STACKS ##
##########################
echo "---> Delete orphaned stacks"

# Search for stacks that are not in use by either releng or sandbox silos and
# delete them.
for STACK_NAME in "${OS_STACKS[@]}"; do
    echo "Checking if orphaned $STACK_NAME"

    # JENKINS_URLS is provided by the Jenkins Job declaration and intentially
    # needs to be globbed.
    # shellcheck disable=SC2153,SC2086
    if stack_in_jenkins "$STACK_NAME" $JENKINS_URLS; then
        # No need to delete stacks if there exists an active build for them
        continue
    else
        status=$(openstack stack show -f value -c "stack_status" "$STACK_NAME")
        case "$status" in
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

                echo "------------------------------------"
                echo "Stack details"
                echo "------------------------------------"
                openstack stack show "$STACK_NAME" -f yaml
                echo "------------------------------------"
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
