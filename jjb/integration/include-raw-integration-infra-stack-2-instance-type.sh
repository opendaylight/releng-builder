#!/bin/bash
# Setup openstack envirnoment file for use by the opendaylight-infra-stack macro
#
# This file is intended for csit labs that need 2 vm types to spin up typically
# controller and mininet but can be used for other combinations.
#
# All parameters in curly braces below are required parameters passed in by JJB.

cat > $WORKSPACE/opendaylight-infra-environment.yaml << EOF
parameters:
    vm_0_count: {vm_0_count}
    vm_0_flavor: {vm_0_flavor}
    vm_0_image: {vm_0_image}
    vm_1_count: {vm_1_count}
    vm_1_flavor: {vm_1_flavor}
    vm_1_image: {vm_1_image}
EOF
echo "Contents of opendaylight-infra-environment.yaml ..."
cat $WORKSPACE/opendaylight-infra-environment.yaml
