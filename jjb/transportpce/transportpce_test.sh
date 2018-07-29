#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Ahmed Triki (Orange Labs) - Initial implementation
##############################################################################

set +e  #DO NOT exit the test process if any of the tests fails
cd tests
echo "test of portmapping"
tox -e portmapping
echo "test of correspondance topology portmapping"
tox -e topoPortMapping
echo "test of topology"
tox -e topology
echo "test of pce"
tox -e pce
echo "test of servicehandler"
tox -e servicehandler
cd ..
