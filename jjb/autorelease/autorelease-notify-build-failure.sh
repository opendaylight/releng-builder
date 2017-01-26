#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

awk '/Reactor Summary:/{flag=1;next}/Final Memory:/{flag=0}flag' log | grep '. FAILURE \[' | awk '{ print $2 }'

echo "Hello" | mail -s "Autorelease build status" thanh.ha@linuxfoundation.org
