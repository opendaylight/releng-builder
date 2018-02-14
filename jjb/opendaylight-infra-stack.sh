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

cd /builder/openstack-hot || exit 1

JOB_SUM=$(echo "$JOB_NAME" | sum | awk '{{ print $1 }}')
VM_NAME="$JOB_SUM-$BUILD_NUMBER"

OS_TIMEOUT=15  # Minutes to wait for OpenStack VM to come online
STACK_RETRIES=2  # Number of times to retry creating a stack before fully giving up
STACK_SUCCESSFUL=false
# seq X refers to waiting for X minutes for OpenStack to return
# a status that is not CREATE_IN_PROGRESS before giving up.
openstack limits show --absolute
openstack limits show --rate
echo "Trying up to $STACK_RETRIES times to create $STACK_NAME."
for try in $(seq $STACK_RETRIES); do
    # shellcheck disable=SC1083
    openstack stack create --timeout "$OS_TIMEOUT" -t {stack-template} -e "$WORKSPACE/opendaylight-infra-environment.yaml" --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" "$STACK_NAME"
    echo "$try: Waiting for $OS_TIMEOUT minutes to create $STACK_NAME."
    for i in $(seq $OS_TIMEOUT); do
        sleep 60
        OS_STATUS=$(openstack stack show -f value -c stack_status "$STACK_NAME")
        echo "$i: $OS_STATUS"

        case "$OS_STATUS" in
            CREATE_COMPLETE)
                echo "Stack initialized on infrastructure successful."
                STACK_SUCCESSFUL=true
                break
            ;;
            CREATE_FAILED)
                reason=$(openstack stack show "$STACK_NAME" -f value -c stack_status_reason)
                echo "ERROR: Failed to initialize infrastructure. Reason: $reason"
                openstack stack resource list -n 25 "$STACK_NAME"

                echo "Deleting stack and possibly retrying to create..."
                openstack stack delete --yes "$STACK_NAME"

                # after stack delete, poll for 10m to know when stack is fully removed
                # the logic here is that when "stack show $STACK_NAME" does not contain $STACK_NAME
                # we assume it's successfully deleted and we can break to retry
                for j in $(seq 20); do
                    sleep 30
                    delete_status=$(openstack stack show "$STACK_NAME" -f value -c stack_status)
                    echo "$j: $delete_status"
                    if [[ $delete_status == "DELETE_FAILED" ]]; then
                        reason=$(openstack stack show "$STACK_NAME" -f value -c stack_status_reason)
                        echo "ERROR: Failed to delete $STACK_NAME. Reason: $reason"

                        # Abandon is not supported in Vexxhost so let's keep trying to
                        # delete for now...
                        # echo "Stack delete failed, trying to stack abandon now."
                        # openstack stack abandon "$STACK_NAME"
                        echo "Deleting failed stack: $STACK_NAME"
                        openstack stack delete --yes "$STACK_NAME"
                    fi

                    if ! openstack stack show "$STACK_NAME" -f value -c stack_status; then
                        echo "Stack show on $STACK_NAME came back empty. Assuming successful delete"
                        break
                    fi
                done

                # If we still see $STACK_NAME in `openstack stack show` it means the delete hasn't fully
                # worked and we can exit forcefully
                if openstack stack show "$STACK_NAME" -f value -c stack_status; then
                    echo "Stack $STACK_NAME still in cloud output after polling. Quitting!"
                    exit 1
                fi
                break
            ;;
            CREATE_IN_PROGRESS)
                echo "Waiting to initialize infrastructure."
                continue
            ;;
            *)
                echo "Unexpected status: $OS_STATUS"
                # DO NOT exit on unexpected status. Rackspace sometimes returns unexpected status
                # before returning an expected status. Just print the message and loop until we have
                # a confirmed state or timeout.
                # exit 1
            ;;
        esac
    done
    if $STACK_SUCCESSFUL; then
        break
    fi
done

# capture stack info in console logs
echo "------------------------------------"
echo "Stack details"
echo "------------------------------------"
openstack stack show "$STACK_NAME" -f yaml
echo "------------------------------------"

if ! $STACK_SUCCESSFUL; then
    exit 1
fi
