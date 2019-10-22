#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Create a python script to parse a Jenkins build for sub-project status

script=$(mktemp)

cat > "$script" <<EOF
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

__author__ = 'Thanh Ha'


import sys

from bs4 import BeautifulSoup
import requests


build_url = sys.argv[1]
urlparse = requests.utils.urlparse(build_url)
jenkins_url = "{}://{}".format(urlparse.scheme, urlparse.netloc)

page = requests.get(build_url)
soup = BeautifulSoup(page.text, 'html.parser')
links = soup.findAll("a", { "class" : "model-link" })

_file = open('csit_failed_tests.txt', 'w+')

for link in links:
    if link.img and (link.img['alt'] == 'Unstable' or
                     link.img['alt'] == 'Failed' or
                     link.img['alt'] == 'Aborted'):

        url = link['href']
        project = url.split('/')[3].split('-')[0]
        _file.write("{}\\t{}{}\\n".format(project, jenkins_url, url))

_file.close()
EOF

virtualenv --quiet "/tmp/v/jenkins"
# shellcheck source=/tmp/v/jenkins/bin/activate disable=SC1091
source "/tmp/v/jenkins/bin/activate"
pip install --quiet --upgrade "pip<10.0.0" setuptools
pip install --quiet --upgrade tox
pip install --quiet --upgrade beautifulsoup4
pip install --quiet --upgrade requests

echo python "$script" "$BUILD_URL"
python "$script" "$BUILD_URL"

mkdir -p "$WORKSPACE/archives"
mv csit_failed_tests.txt "$WORKSPACE/archives"
