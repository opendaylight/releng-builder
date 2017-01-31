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


WAIT_TIME=0
MAX_WAIT=5
until OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'` || [ $WAIT_TIME -eq $MAX_WAIT ]; do
   sleep $(( WAIT_TIME++ ))
   if [ "$OS_STATUS" == "CREATE_COMPLETED" ]; then
       echo "Stack initialized on infrastructure successful."
       exit 0
   elif [ "$OS_STATUS" == "CREATE_FAILED" ]; then
       echo "ERROR: Failed to initialize infrastructure. Quitting..."
       exit 1
   elif [ "$OS_STATUS" == "CREATE_IN_PROGRESS" ]; then
       echo "Waiting to initialize infrastructure ${{MAX_WAIT-WAIT_TIME}}"
       continue
   fi
done
