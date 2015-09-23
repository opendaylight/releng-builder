#!/bin/bash

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

virtualenv $WORKSPACE/venv-robotframework
source $WORKSPACE/venv-robotframework/bin/activate
pip install -q docker-py importlib requests scapy
pip install -q robotframework{,-{httplibrary,requests,sshlibrary}}

# vim: sw=4 ts=4 sts=4 et ft=sh :
