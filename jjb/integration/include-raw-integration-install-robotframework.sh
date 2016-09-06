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

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv --system-site-packages ${ROBOT_VENV}
source ${ROBOT_VENV}/bin/activate

set -exu

# Make sure pip itself us up-to-date.
pip install --upgrade pip

pip install --upgrade docker-py importlib requests scapy netifaces netaddr ipaddr python-neutronclient
pip install --upgrade robotframework{,-{httplibrary,requests,sshlibrary,selenium2library}}

# Module jsonpath is needed by current AAA idmlite suite.
pip install --upgrade jsonpath-rw

# Modules for longevity framework robot library
pip install elasticsearch==1.7.0 elasticsearch-dsl==0.0.11

# Module for pyangbind used by lispflowmapping project
pip install pyangbind==0.5.6

# Print installed versions.
pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
