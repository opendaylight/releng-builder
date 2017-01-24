#!/bin/bash

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

HOST=$(/bin/hostname)
SYSTEM_TYPE=''

IFS=','
for i in "java-builder,builder" \
         "devstack,devstack" \
         "docker,docker" \
         "gbp,ubuntu-docker-ovs" \
         "matrix,matrix" \
         "robot,robot" \
         "ubuntu-trusty-mininet,mininet-ubuntu" \
         "mininet,mininet-ubuntu"
do set -- $i
    if [[ $HOST == *"$1"* ]]; then
        SYSTEM_TYPE="$2"
        break
    fi
done

# Write out the system type to an environment file to then be sourced
echo "SYSTEM_TYPE=${SYSTEM_TYPE}" > /tmp/system_type.sh

# vim: sw=4 ts=4 sts=4 et :
