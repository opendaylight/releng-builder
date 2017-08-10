#!/bin/bash
# shellcheck disable=SC2034,SC2154
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system="releng"
search_string="{search_string}"
blacklist_in="{blacklist}"
# shellcheck disable=SC1083
blacklist=( $(echo ${{blacklist_in}}) )
stream="{stream}"

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $search_string | grep $stream)

# shellcheck disable=SC1083
{
# shellcheck disable=SC2124
bl_len=${{#blacklist[@]}}
for i in $(seq 0 ${{bl_len}}); do
    jobs="$(echo "$jobs" | grep -v ${{blacklist[$i]}})"
done
}
# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > {jobs-filename}
