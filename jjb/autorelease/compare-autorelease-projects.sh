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

# This script performs version bumping activities for an ODL release.
echo "---> validate-projects.sh"

# The purpose of this script is to compare list of projects in autorelease
# are equal to the list of projects in integration/distribution.

PROJECTS_INT_DIST=( $(xmlstarlet sel\
     -N x=http://maven.apache.org/POM/4.0.0\
     -t\
     --if "/x:project/x:dependencies/x:dependency/x:groupId"\
     -v "/x:project/x:dependencies/x:dependency/x:groupId"\
     --elif "/x:project/x:profiles/x:profile/x:dependencies/x:dependency/x:groupId"\
     -v "/x:project/x:profiles/x:profile/x:dependencies/x:dependency/x:groupId"\
     --else -o ""\
     integration/distribution/features/repos/index/pom.xml | sort | uniq) )

# process projects in int/dist read from pom.xml file
declare -a project_int_dist
for p in "${PROJECTS_INT_DIST[@]}"; do
    if [[ $p =~ honeycomb.vbd ]]; then
        project_int_dist+=("honeycomb/vbd")
    elif [[ $p =~ project.groupId ]] || [[ $p =~ odlparent ]]; then
        continue
    elif [[ $p =~ org.opendaylight ]]; then
        project_int_dist+=( $(echo "$p" | awk -F. '{print $3}') )
    else
        project_int_dist+=("$p")
    fi
done

# Also add int/dist project in the list
project_int_dist+=("integration/distribution")

# Get a list of all the project in AR
declare -a projects_AR
project_AR=( $(git submodule status | awk -e '{print $2}' | sort | uniq) )

declare -A temp_array1 temp_array2
for project in "${project_AR[@]}"
do
    ((temp_array1[$project]++))
done

for project in "${project_int_dist[@]}"
do
    ((temp_array2[$project]++))
done

for project in "${!temp_array1[@]}"
do
    if (( ${temp_array1[$project]} >= 1 && ${temp_array2[$project]-0} >= 1 )); then
        unset "temp_array1[$project]" "temp_array2[$project]"
    fi
done

result=(${!temp_array1[@]} ${!temp_array2[@]})

if [ "${#result[@]}" != "0" ]; then
    echo "ERROR: List of projects mismatch in releng/autorelease and integration/distribution: ${result[@]}"
    [[ "${#temp_array1[@]}" != "0"  ]] && echo "releng/autorelease: ${!temp_array1[@]}"
    [[ "${#temp_array2[@]}" != "0"  ]] && echo "integration/distribution: ${!temp_array2[@]}"
    exit 1
else
    echo "List of projects releng/autorelease and integration/distribution repositoies are equal"
fi
