#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 - 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> Cleanup stale nodes"

# Todo: As a safe check we could obtain the list of active jobs from Jenkins and
# compute the checksum from $JOB_NAME to check if any active nodes exist and
# skip deleting those nodes. This step may not be required since there is already
# 24H timeout in place for all jobs therefore all jobs are expected to complete
# within the timeout.

lftools openstack --os-cloud vex server list --days=1
lftools openstack --os-cloud vex server cleanup --days=1
