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

mkdir -p archives/sar
cp /var/log/sa/* $_
# convert sar data to ascii format
while IFS="" read -r s
do
    [ -f "$s" ] && sar -A -f "$s" > archives/sar/sar${s//[!0-9]/}
done < <(find /var/log/sa -name "sa[0-9]*")
