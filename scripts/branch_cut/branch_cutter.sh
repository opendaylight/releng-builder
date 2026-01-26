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
# MRI projects use version-specific branches (e.g. controller 12.0.x)
# and require project leader approval to branch
declare -a excludes=("defaults.yaml"
                     "releng-macros.yaml"
                     "global-jjb"
                     "lf-infra"
                     "-macros.yaml"
                     "validate-autorelease"
                     "opflex-dependencies.yaml"
                     "jjb/aaa/"
                     "jjb/bgpcep/"
                     "jjb/controller/"
                     "jjb/infrautils/"
                     "jjb/mdsal/"
                     "jjb/netconf/"
                     "jjb/odlparent/"
                     "jjb/yangtools/")

TEMP="/tmp/tmp.yaml"
mod=0
count=0

function usage {
    echo "Usage: $(basename "$0") options (-c [current release]) (-n [next release]) (-p [previous release]) (-e [EOL release]) -h for help";
    echo ""
    echo "For branch cutting:"
    echo "  branch_cutter.sh -n oxygen -c nitrogen -p carbon [-e boron]"
    echo ""
    echo "For EOL removal only:"
    echo "  branch_cutter.sh -e boron"
    exit 0;
}

if ( ! getopts ":n:c:p:e:h" opt ); then
    usage;
fi

while getopts ":n:c:p:e:h" opt; do
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
        e)
            eol_reltag=$OPTARG
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

# Check if at least one parameter is provided
if [[ -z "$new_reltag" && -z "$curr_reltag" && -z "$prev_reltag" && -z "$eol_reltag" ]]; then
    echo "Error: At least one parameter must be provided"
    usage
fi

# Validate: if doing branch cut (new/curr/prev), all three must be provided
if [[ -n "$new_reltag" || -n "$curr_reltag" || -n "$prev_reltag" ]]; then
    if [[ -z "$new_reltag" || -z "$curr_reltag" || -z "$prev_reltag" ]]; then
        echo "Error: For branch cutting, -n, -c, and -p are all required"
        usage
    fi
fi

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
        ./branch_cut.awk -v new_reltag="$new_reltag" -v curr_reltag="$curr_reltag" -v prev_reltag="$prev_reltag" -v eol_reltag="$eol_reltag" "$file" > "$TEMP"
        [[ ! -s "$TEMP" ]] && echo "$file: excluded"
        [[ -s "$TEMP" ]] && mv "$TEMP" "$file" && echo "$file: Done" && (( mod++ ))
        (( count++ ))
    fi
done < <(find ../../jjb -name "*.yaml")

echo "Modified $mod out of $count files"
echo "Completed"
