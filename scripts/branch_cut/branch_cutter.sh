#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
##############################################################################

# List of directories, files to exclude
declare -a excludes=("defaults.yaml"
                     "releng-macros.yaml"
                     "global-jjb"
                     "lf-infra"
                     "-macros.yaml"
                     "validate-autorelease"
                     "opflex-dependencies.yaml")

TEMP="/tmp/tmp.yaml"
mod=0
count=0

function usage {
    echo "Usage: $(basename "$0") options (-c [current release]) (-n [next release]) (-p [previous release]) -h for help";
    echo "example:"
    echo "branch_cutter.sh -n oxygen -c nitrogen -p carbon"
    exit 0;
}

if ( ! getopts ":n:c:p:h" opt ); then
    usage;
fi

while getopts ":n:c:p:h" opt; do
    case $opt in
        n)
            new_reltag=$OPTARG
            ;;
        c)
            curr_reltag=$OPTARG
            ;;
        p)
            prev_reltag=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        h)
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

echo "Start Branch Cutting:"

while IFS="" read -r file; do
    found=0
    for exclude in "${excludes[@]}"; do
        if [[ $file =~ $exclude && $found -eq 0 ]]; then
            found=1
            break
        fi
    done
    if [[ $found -eq 1 ]]; then
        echo "Ignore file $file found in excludes list"
    else
        ./branch_cut.awk -v new_reltag="$new_reltag" -v curr_reltag="$curr_reltag" -v prev_reltag="$prev_reltag" "$file" > "$TEMP"
        [[ ! -s "$TEMP" ]] && echo "$file: excluded"
        [[ -s "$TEMP" ]] && mv "$TEMP" "$file" && echo "$file: Done" && (( mod++ ))
        (( count++ ))
    fi
done < <(find ../../jjb -name "*.yaml")

echo "Modified $mod out of $count files"
echo "Completed"
