#!/bin/bash

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
##############################################################################

# List of files to be excluded
excludes=(autorelease-projects.yaml
          integration-test-jobs.yaml
          opflex-dependencies.yaml)

TEMP="/tmp/tmp.yaml"
mod=0
count=0

echo "Start Branch Cutting:"
while IFS="" read -r y; do
    if [[ ! "${excludes[@]}" =~ $y ]]; then
        ./branch_cut.awk "$y" > "$TEMP"
        [[ ! -s "$TEMP" ]] && echo "$y: excluded"
        [[ -s "$TEMP" ]] && mv "$TEMP" "$y" && echo "$y: Done" && let "mod++"
        let "count++"
    fi
done < <(find ../../jjb -name "*.yaml")

echo "Modified $mod out of $count files"
echo "Completed"
