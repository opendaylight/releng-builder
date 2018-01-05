#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Ensures that we are only ever using one robot system
#
# Due to the way the Jenkins OpenStack Cloud plugin works we can only limit
# max parallel robot systems by the VM. So having multiple VM types makes it
# very difficult for us to properly limit the amount of parallel robot runs.

robots=$(find . -name "*.yaml" | xargs grep centos7-robot | awk '{print $NF}' \
    | sort | uniq | wc -l)

if [ "$robots" -gt 1 ]; then
    echo "ERROR: More than one robot system type definition detected."
    echo "Please ensure that ALL templates use the same robot nodes."
    echo "Infra does not support more than 1 robot node type in use."
    exit 1
fi
