#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

cd /builder/jenkins-scripts || exit 1
chmod +x -- *.sh
./system_type.sh

# shellcheck disable=SC1091
source /tmp/system_type.sh
./basic_settings.sh
"./${SYSTEM_TYPE}.sh"

# Create the jenkins user last so that hopefully we don't have to deal with
# guard files
./create_jenkins_user.sh

## add local environment changes post scripts
./jenkins-init-script-local-env.sh

# Create a swap file
fallocate -l 1G /swap
chmod 600 /swap
mkswap /swap
swapon /swap
