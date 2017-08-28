#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

lftools openstack --os-cloud odlpriv-sandbox \
    image cleanup --hide-public=True \
                  --days=30 \
                  --clouds=odlpriv-sandbox,rackspace
