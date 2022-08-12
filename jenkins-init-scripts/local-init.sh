#!/bin/sh
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

INIT_DIR=$(dirname $0)
# used to be "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# this is the closest equivalent in POSIX
# it might give issues in rare circumstances
"${INIT_DIR}/system_type.sh"
# shellcheck disable=SC1091
. /tmp/system_type.sh
"${INIT_DIR}/${SYSTEM_TYPE}.sh"
