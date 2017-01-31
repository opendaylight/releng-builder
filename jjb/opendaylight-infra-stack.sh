#!/bin/bash
virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

cd /builder/openstack-hot

JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"
openstack --os-cloud rackspace stack create --wait --timeout 15 -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME

MAX_WAIT=30
WAIT_TIME=1
while true; do
    ((WAIT_TIME++))
    if [ $WAIT_TIME -lt $MAX_WAIT ]; then
        OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`
        if [ "$OS_STATUS" == "CREATE_COMPLETE" ]; then
            echo "Stack initialized on infrastructure successful."
            exit 0
        elif [ "$OS_STATUS" == "CREATE_FAILED" ]; then
            echo "ERROR: Failed to initialize infrastructure. Quitting..."
            break
        elif [ "$OS_STATUS" == "CREATE_IN_PROGRESS" ]; then
            let WAIT=${{MAX_WAIT-WAIT_TIME}}/2
            echo "Waiting to initialize infrastructure: $WAIT minutes"
            sleep 30
            continue
        fi
    fi
done

# notify publisher on timeout or failure
if [[ $? -ne 0 ]] || [[ $WAIT_TIME -eq $MAX_WAIT ]]; then
    echo > "1" $WORKSPACE/tmp_stack_create_status
fi
