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

ROBOT_VENV=`mktemp -d --suffix=robot_venv`
echo ROBOT_VENV=${ROBOT_VENV} >> ${WORKSPACE}/env.properties

virtualenv ${ROBOT_VENV}
source ${ROBOT_VENV}/bin/activate

set -exu

pip install --upgrade pip

# The most recent version of paramiko currently fails to install.
pip install --upgrade docker-py importlib requests scapy netifaces netaddr ipaddr
pip install --upgrade robotframework{,-{httplibrary,requests,sshlibrary,selenium2library}}

# jsonpath is needed by current AAA idmlite suite
pip install --upgrade jsonpath-rw

# print installed versions
pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
