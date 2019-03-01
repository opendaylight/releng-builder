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
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv --system-site-packages "${ROBOT_VENV}"
# shellcheck disable=SC1090
source "${ROBOT_VENV}/bin/activate"

set -exu

# Make sure pip itself us up-to-date.
pip install --upgrade pip
pip3 install --upgrade pip

pip install --upgrade docker-py importlib requests scapy netifaces netaddr ipaddr pyhocon
pip install --upgrade robotframework-httplibrary \
    requests==2.15.1 \
    robotframework-requests \
    robotframework-sshlibrary==3.1.1 \
    robotframework-selenium2library \
    robotframework-pycurllibrary

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
pip3 install --user https://files.pythonhosted.org/packages/63/cb/6965947c13a94236f6d4b8223e21beb4d576dc72e8130bd7880f600839b8/urllib3-1.22-py2.py3-none-any.whl
pip3 install --user https://files.pythonhosted.org/packages/b8/f7/3bb4d18c234a8ce7044d5ee2e1082b7d72bf6c550afb8d51ae266dea56f1/requests-2.9.1-py2.py3-none-any.whl
pip3 install --user https://files.pythonhosted.org/packages/c3/e3/146b675e6d0138a49c4b817b4e68170eb9b75cee7e71fa3ec69624c4f467/elasticsearch-6.2.0-py2.py3-none-any.whl
pip3 install --user https://files.pythonhosted.org/packages/75/5e/b84feba55e20f8da46ead76f14a3943c8cb722d40360702b2365b91dec00/PyYAML-3.11.tar.gz

# odltools for extra debugging
pip install odltools
odltools -V

# Print installed versions.
pip install --upgrade pipdeptree
pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
