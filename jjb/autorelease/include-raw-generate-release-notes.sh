#!/bin/bash -x
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015, 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

cd $WORKSPACE/scripts/release_notes_management
# replace mvn command with the executable path
sed -i -s "s#mvn#/w/tools/hudson.tasks.Maven_MavenInstallation/mvn33/bin/mvn#" ./build.sh
./build.sh
