#!/bin/bash

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Thanh Ha (The Linux Foundation) - Initial implementation
##############################################################################

# Clear workspace
rm -rf *

# Create python script to parse json
cat > ${WORKSPACE}/parse_json.py << EOF
import json
import sys

obj=json.load(sys.stdin)
for key in obj.keys():
    print(key)

EOF

# Clone all ODL projects
curl -s --header "Accept: application/json" \
    https://git.opendaylight.org/gerrit/projects/ | \
    tail -n +2 > ${WORKSPACE}/projects.json
for p in `cat ${WORKSPACE}/projects.json | python ${WORKSPACE}/parse_json.py`
do
    # Ignore non-projects and archived projects
    if [ "$p" == "All-Users" ] || \
       [ "$p" == "affinity" ] || \
       [ "$p" == "integration" ] || \
       [ "$p" == "net-virt-platform" ] || \
       [ "$p" == "opendove" ] || \
       [ "$p" == "plugin2oc" ]
    then
        continue
    fi
    mkdir -p `dirname "$p"`
    git clone "https://git.opendaylight.org/gerrit/$p.git" "$p"
done

# Check pom.xml for <repositories> and <pluginRepositories>
FILE=repos.txt

find . -name pom.xml | xargs grep -i '<repositories>\|<pluginRepositories>' > $FILE
[[ $(tr -d "\r\n" < $FILE|wc -c) -eq 0 ]] && rm $FILE

if [ -a $FILE ]
then
    cat $FILE
    echo "[ERROR] Repos with <repositories> and/or <pluginRepositories> sections found!"
    exit 1
fi
