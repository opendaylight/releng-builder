#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

ROBOT_VENV="/tmp/v/robot"
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv -p python3 --system-site-packages "${ROBOT_VENV}"
# shellcheck disable=SC1090
source "${ROBOT_VENV}/bin/activate"

set -exu

# Make sure pip itself us up-to-date.
pip install --upgrade pip
python3 -m pip install --user --upgrade pip

pip install --upgrade docker-py importlib requests scapy netifaces netaddr ipaddr pyhocon
pip install --upgrade robotframework-httplibrary \
    requests==2.15.1 \
    robotframework-requests \
    robotframework-sshlibrary==3.1.1 \
    robotframework-selenium2library

# Module jsonpath is needed by current AAA idmlite suite.
pip install --upgrade jsonpath-rw

# Modules for longevity framework robot library
pip install --upgrade elasticsearch==1.7.0 elasticsearch-dsl==0.0.11

# Module for pyangbind used by lispflowmapping project
pip install --upgrade pyangbind

# Module for iso8601 datetime format
pip install --upgrade isodate

# Module for TemplatedRequests.robot library
pip install --upgrade jmespath

# Module for backup-restore support library
pip install --upgrade jsonpatch

#Module for elasticsearch python client
#Module for elasticsearch python client
#pip install urllib3==1.22
#pip install requests==2.9.1
#pip install elasticsearch==6.2.0
#pip install PyYAML==3.11

# odltools for extra debugging
pip install odltools
odltools -V

# Print installed versions.
pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
