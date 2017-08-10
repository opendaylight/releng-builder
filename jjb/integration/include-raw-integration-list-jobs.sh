#!/bin/bash
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system="releng"
# shellcheck disable=SC2034
blacklist=( $(echo "$BLACKLIST") )

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $SEARCH_STRING | grep $STREAM;)

# shellcheck disable=SC2154
bl_len="${{#blacklist[*]}}"
for i in $(seq 0 "$bl_len"); do
    # shellcheck disable=SC2154
    jobs="$(echo "$jobs" | grep -v "${{blacklist[$i]}}")"
done

# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > "${{JOBS_FILENAME}}"
