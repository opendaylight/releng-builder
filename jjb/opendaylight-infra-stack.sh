#!/bin/bash
virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

cd /builder/openstack-hot

JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"

OS_TIMEOUT=10  # Minutes to wait for OpenStack VM to come online
STACK_RETRIES=3  # Number of times to retry creating a stack before fully giving up
STACK_SUCCESSFUL=false
# seq X refers to waiting for X minutes for OpenStack to return
# a status that is not CREATE_IN_PROGRESS before giving up.
openstack --os-cloud rackspace limits show --absolute
openstack --os-cloud rackspace limits show --rate
openstack --os-cloud rackspace stack create --timeout $OS_TIMEOUT -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME
echo "Trying up to $STACK_RETRIES times to create $STACK_NAME."
for try in `seq $STACK_RETRIES`; do
    echo "Waiting for $OS_TIMEOUT minutes to create $STACK_NAME."
    for i in `seq $OS_TIMEOUT`; do
        sleep 60
        OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`

        case "$OS_STATUS" in
            CREATE_COMPLETE)
                echo "Stack initialized on infrastructure successful."
                STACK_SUCCESSFUL=true
                break
            ;;
            CREATE_FAILED)
                echo "ERROR: Failed to initialize infrastructure. Quitting..."
                break
            ;;
            CREATE_IN_PROGRESS)
                echo "Waiting to initialize infrastructure."
                continue
            ;;
            *)
                echo "Unexpected status: $OS_STATUS"
                break
            ;;
        esac
    done
    if $STACK_SUCCESSFUL; then
        break
    fi
done

# capture stack info in console logs
openstack --os-cloud rackspace stack show $STACK_NAME

if ! $STACK_SUCCESSFUL; then
    exit 1
fi
