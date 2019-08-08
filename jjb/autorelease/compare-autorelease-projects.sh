#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script performs version bumping activities for an ODL release.
echo "---> compare-autorelease-projects.sh"

# The purpose of this script is to compare list of projects in autorelease
# are equal to the list of projects in integration/distribution.

mapfile -t PROJECTS_INT_DIST < <(xmlstarlet sel\
     -N "x=http://maven.apache.org/POM/4.0.0"\
     -t -m "/x:project/x:profiles/x:profile[x:activation/x:activeByDefault='true']/x:dependencies/x:dependency/x:groupId"\
     -v .\
     -n integration/distribution/features/repos/index/pom.xml 2>/dev/null | sort -u)

# process projects in int/dist read from pom.xml file
declare -a project_int_dist
for project in "${PROJECTS_INT_DIST[@]}"; do
    if [[ $project =~ project.groupId ]] || [[ $project =~ odlparent ]]; then
        continue
    elif [[ $project =~ org.opendaylight ]]; then
        project=${project/org.opendaylight./}
        project_int_dist+=("${project/.//}")
    fi
done

project_int_dist+=("integration/distribution")

# Get a list of all the projects from releng/autorelease repo
declare -a project_AR
mapfile -t project_AR < <(git submodule status | awk -e '{print $2}' | sort | uniq)

# Use associative arrays to get diff in the projects lists
declare -A map_AR map_intdist
for project in "${project_AR[@]}"
do
    ((map_AR[$project]++))
done

for project in "${project_int_dist[@]-0}"
do
    ((map_intdist[$project]++))
done

for project in "${!map_AR[@]}"
do
    if (( ${map_AR[$project]} >= 1 && ${map_intdist[$project]-0} >= 1 )); then
        unset "map_AR[$project]" "map_intdist[$project]"
    fi
done

result=("${!map_AR[@]}" "${!map_intdist[@]}")

if [ "${#result[@]}" != "0" ]; then
    if [ "${#map_AR[@]}" != "0"  ]; then
        echo "WARNING: List of projects in releng/autorelease but NOT in integration/distribution: ${!map_AR[*]}"
    elif [ "${#map_intdist[@]}" != "0"  ]; then
        echo "ERROR: List of projects in integration/distribution but NOT in releng/autorelease: ${!map_intdist[*]}"
        exit 1
    fi
else
    echo "List of projects releng/autorelease and integration/distribution repositories are equal"
fi
