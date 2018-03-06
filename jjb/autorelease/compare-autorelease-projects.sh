#!/bin/bash
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
echo "---> compare-AutoRelease-projects.sh"

# The purpose of this script is to compare list of projects in autorelease
# are equal to the list of projects in integration/distribution.

mapfile -t PROJECTS_INT_DIST < <(xmlstarlet sel\
     -N x=http://maven.apache.org/POM/4.0.0\
     -t\
     --if "/x:project/x:dependencies/x:dependency/x:groupId"\
     -v "/x:project/x:dependencies/x:dependency/x:groupId"\
     --elif "/x:project/x:profiles/x:profile/x:dependencies/x:dependency/x:groupId"\
     -v "/x:project/x:profiles/x:profile/x:dependencies/x:dependency/x:groupId"\
     --else -o ""\
     integration/distribution/features/repos/index/pom.xml | sort | uniq)

# process projects in int/dist read from pom.xml file
declare -a project_int_dist
for project in "${PROJECTS_INT_DIST[@]}"; do
    if [[ $project =~ project.groupId ]] || [[ $project =~ odlparent ]]; then
        continue
    elif [[ $project =~ org.opendaylight ]]; then
        project=$(echo "${project/org.opendaylight./}")
        project_int_dist+=( "$(echo "${project/.//}" )" )
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

for project in "${project_int_dist[@]}"
do
    ((map_intdist[$project]++))
done

for project in "${!map_AR[@]}"
do
    if (( ${map_AR[$project]} >= 1 && ${map_intdist[$project]-0} >= 1 )); then
        unset "map_AR[$project]" "map_intdist[$project]"
    fi
done

mapfile -t result < <(echo "${!map_AR[@]}" "${!map_intdist[@]}")

if [ "${#result[@]}" != "0" ]; then
    echo "ERROR: List of projects mismatch in releng/autorelease and integration/distribution: ${result[*]}"
    [[ "${#map_AR[@]}" != "0"  ]] && echo "releng/autorelease: ${!map_AR[*]}"
    [[ "${#map_intdist[@]}" != "0"  ]] && echo "integration/distribution: ${!map_intdist[*]}"
    exit 1
else
    echo "List of projects releng/autorelease and integration/distribution repositoies are equal"
fi
