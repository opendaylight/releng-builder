#!/bin/bash
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system="releng"
declare -a blacklist=( $(echo "$BLACKLIST") )
echo "$BLACKLIST" > "$WORKSPACE/archives/integration-list-job-blacklist.log" 2>&1

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $SEARCH_STRING | grep $STREAM;)

# SC2154 expects var is referenced but not assigned. However the blacklist array
# is returns the length of the array and not the array itself, therefore disable
# the check.
# shellcheck disable=SC2154
bl_len="${#blacklist[*]}"
for i in $(seq 0 "$bl_len"); do
    # shellcheck disable=SC2154
    jobs="$(echo "$jobs" | grep -v "${blacklist[$i]}")"
done

# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > "${JOBS_FILENAME}"
