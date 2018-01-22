#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 - 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Removes openstack images older than 30 days in the cloud

# shellcheck source=/tmp/v/lftools/bin/activate disable=SC1091
source "/tmp/v/lftools/bin/activate"
lftools openstack --os-cloud vex image cleanup --days=30
