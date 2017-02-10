#!/bin/bash
virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
PYTHON="$WORKSPACE/.venv-openstack/bin/python"
OPENSTACK=$WORKSPACE/.venv-openstack/bin/openstack
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install --upgrade python-openstackclient python-heatclient
$PYTHON -m pip freeze

cd /builder/openstack-hot

JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"

# seq X refers to waiting for X minutes for OpenStack to return
# a status that is not CREATE_IN_PROGRESS before giving up.
OS_TIMEOUT=15  # Minutes to wait for OpenStack VM to come online
$PYTHON $OPENSTACK --os-cloud rackspace limits show --absolute
$PYTHON $OPENSTACK --os-cloud rackspace limits show --rate
$PYTHON $OPENSTACK --os-cloud rackspace stack create --timeout $OS_TIMEOUT -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME
echo "Waiting for $OS_TIMEOUT minutes to create $STACK_NAME."
for i in `seq $OS_TIMEOUT`; do
    sleep 60
    OS_STATUS=`$PYTHON $OPENSTACK --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`

    case "$OS_STATUS" in
        CREATE_COMPLETE)
            echo "Stack initialized on infrastructure successful."
            break
        ;;
        CREATE_FAILED)
            echo "ERROR: Failed to initialize infrastructure. Quitting..."
            exit 1
        ;;
        CREATE_IN_PROGRESS)
            echo "Waiting to initialize infrastructure."
            continue
        ;;
        *)
            echo "Unexpected status: $OS_STATUS"
            exit 1
        ;;
    esac
done

# capture stack info in console logs
$PYTHON $OPENSTACK --os-cloud rackspace stack show $STACK_NAME
