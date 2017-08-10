#!/bin/bash
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system="releng"
declare -a blacklist=( $(echo "$BLACKLIST") )
echo "$BLACKLIST" > "$WORKSPACE/archives/integration-list-job-blacklist.log" 2>&1

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $SEARCH_STRING | grep $STREAM;)

for item in "${blacklist[@]}"; do
    jobs=$(echo "$jobs" | grep -v "$item")
done

# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > "${JOBS_FILENAME}"
