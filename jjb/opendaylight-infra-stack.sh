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

for i in `seq 15`; do
    OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`
    if [ "$OS_STATUS" == "CREATE_COMPLETE" ]; then
        echo "Stack initialized on infrastructure successful."
        break
    elif [ "$OS_STATUS" == "CREATE_FAILED" ]; then
        echo "ERROR: Failed to initialize infrastructure. Quitting..."
        break
    elif [ "$OS_STATUS" == "CREATE_IN_PROGRESS" ]; then
        echo "Waiting to initialize infrastructure."
        sleep 60
        continue
    fi
done

# notify publisher the stack create status
echo OS_STATUS="$OS_STATUS" > $WORKSPACE/openstack_env.sh
