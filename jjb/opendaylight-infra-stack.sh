#!/bin/bash
virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

cd /builder/openstack-hot

JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"

# seq X refers to waiting for X minutes for OpenStack to return
# a status that is not CREATE_IN_PROGRESS before giving up.
OS_TIMEOUT=15  # Minutes to wait for OpenStack VM to come online
openstack --os-cloud rackspace stack create --timeout $OS_TIMEOUT -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME
echo "Waiting for $OS_TIMEOUT minutes to create $STACK_NAME."
for i in `seq $OS_TIMEOUT`; do
    sleep 60
    OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`
    if [ "$OS_STATUS" == "CREATE_COMPLETE" ]; then
        echo "Stack initialized on infrastructure successful."
        break
    elif [ "$OS_STATUS" == "CREATE_FAILED" ]; then
        echo "ERROR: Failed to initialize infrastructure. Quitting..."
        exit 1
    elif [ "$OS_STATUS" == "CREATE_IN_PROGRESS" ]; then
        echo "Waiting to initialize infrastructure."
        continue
    else
        echo "Unexpected status: $OS_STATUS"
    fi
done
