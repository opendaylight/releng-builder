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
virtualenv --system-site-packages "${ROBOT_VENV}"
# shellcheck disable=SC1090
source "${ROBOT_VENV}/bin/activate"

set -exu

# Make sure pip itself us up-to-date.
python2 -m pip install --user --upgrade pip
python3 -m pip install --user --upgrade pip

echo "Installing Python 2 Requirements"
cat << 'EOF' > "python2-requirements.txt"
docker-py
importlib
ipaddr
netaddr
netifaces
pyhocon
requests
robotframework-httplibrary
robotframework-pycurllibrary
robotframework-requests
robotframework-selenium2library
robotframework-sshlibrary==3.1.1
scapy

# Module jsonpath is needed by current AAA idmlite suite.
jsonpath-rw

# Modules for longevity framework robot library
elasticsearch==1.7.0
elasticsearch-dsl==0.0.11

# Module for pyangbind used by lispflowmapping project
pyangbind

# Module for iso8601 datetime format
isodate

# Module for TemplatedRequests.robot library
jmespath

# Module for backup-restore support library
jsonpatch

# odltools for extra debugging
odltools
EOF
python2 -m pip install --user -r python2-requirements.txt
odltools -V
pip freeze


echo "Installing Python 3 Requirements"
cat << 'EOF' > "python3-requirements.txt"
urllib3==1.22
requests
elasticsearch==6.2.0
PyYAML==3.11
EOF
python3 -m pip install --user -r python3-requirements.txt
pip3 freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
