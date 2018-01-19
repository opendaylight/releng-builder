#!/bin/bash
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

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv "${ROBOT_VENV}"
# shellcheck disable=SC1090
source "${ROBOT_VENV}/bin/activate"

set -exu

case ${OPENSTACK_BRANCH} in
   *pike)
      pip install python-openstackclient==3.12.0
      pip install networking-l2gw==11.0.0
      pip install python-neutronclient==6.5.0
      pip install networking-sfc==5.0.0
      ;;
   *ocata)
      pip install python-openstackclient==3.8.1
      pip install networking-l2gw==11.0.0
      pip install python-neutronclient==6.1.1
      pip install networking-sfc==5.0.0
      ;;
   *queens)
      pip install python-openstackclient==3.13.0
      pip install networking-l2gw==11.0.0
      pip install python-neutronclient==6.6.0
      pip install networking-sfc==6.0.0.0b2
      ;;
esac
      
# Print installed versions.
pip install --upgrade pipdeptree
pipdeptree

# vim: sw=4 ts=4 sts=4 et ft=sh :
