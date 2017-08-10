#!/bin/bash
# shellcheck disable=SC2034,SC2154
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system="releng"
search_string="$SEARCH_STRING"
blacklist=( $(echo "$BLACKLIST") )
stream="$STREAM"

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $SEARCH_STRING | grep $STREAM)

bl_len=${{#blacklist[@]}}
for i in $(seq 0 "$bl_len"); do
    jobs="$(echo "$jobs" | grep -v "${{blacklist[$i]}}")"
done

# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > {jobs-filename}
