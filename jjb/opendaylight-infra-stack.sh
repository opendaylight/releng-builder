#!/bin/bash
virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

cd /builder/openstack-hot
echo "Inside the builder script"
sudo wget https://git.opendaylight.org/gerrit/cat/50647%2C2%2Copenstack-hot/csit-3-instance-type.yaml
sudo unzip csit-3-instance-type.yaml
sudo rm csit-3-instance-type.yaml
sudo mv csit-3-instance-type_new*.yaml csit-3-instance-type.yaml
ls -lrt
echo "Cat csit-3-instance-type.yaml"
cat csit-3-instance-type.yaml
echo "Environment file"
cat $WORKSPACE/opendaylight-infra-environment.yaml
echo "Echo Over"


JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"
openstack --os-cloud rackspace stack create --wait --timeout 15 -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME
OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`
if [ "$OS_STATUS" != "CREATE_COMPLETE" ]; then
    echo "Failed to initialize infrastructure. Quitting..."
    exit 1
fi
