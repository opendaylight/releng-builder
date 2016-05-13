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

HOST=$(/usr/bin/hostname)
SYSTEM_TYPE=''

# We use a separator character of - for the slave parts
IFS='-' read -r -a HOSTPARTS <<< "${HOST}"

# slurp in the control scripts
FILES=($(find . -maxdepth 1 -type f -iname '*.sh' -exec basename -s '.sh' {} \;))
# remap into an associative array
declare -A A_FILES
for key in "${!FILES[@]}"
do
    A_FILES[${FILES[$key]}]="${key}"
done

# Find our system_type control script if possible
for i in "${HOSTPARTS[@]}"
do
    if [ "${A_FILES[${i}]}" != "" ]
    then
        SYSTEM_TYPE=${i}
        break
    fi
done

# Write out the system type to an environment file to then be sourced
echo "SYSTEM_TYPE=${SYSTEM_TYPE}" > /tmp/system_type.sh

# vim: sw=4 ts=4 sts=4 et :
