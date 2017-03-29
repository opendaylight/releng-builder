#!/bin/bash
if [ -d "$WORKSPACE/.venv-openstack" ]; then
    # shellcheck disable=SC1090
    source "$WORKSPACE/.venv-openstack/bin/activate"
    OS_STATUS=$(openstack --os-cloud rackspace stack show -f json -c stack_status "$STACK_NAME" | jq -r '.stack_status')
    if [ "$OS_STATUS" == "CREATE_COMPLETE" ] || [ "$OS_STATUS" == "CREATE_FAILED" ]; then
        echo "Deleting $STACK_NAME"
        openstack --os-cloud rackspace stack delete --yes "$STACK_NAME"
    fi
fi
