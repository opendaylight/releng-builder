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

cd /builder/jenkins-scripts
chmod +x *.sh
./system_type.sh

source /tmp/system_type.sh
./basic_settings.sh
./create_jenkins_user.sh
./${SYSTEM_TYPE}.sh
