#!/bin/bash
# Script to filter Jenkins jobs against a blacklist
# output: newline & comma-separated list

system=releng
search_string="{search_string}"
if [ -n "$search_string" ] ; then
    search_string=csit
fi

blacklist_in="{blacklist}"
if [ -n "$blacklist_in" ] ; then
    blacklist_in="longevity gate"
fi
blacklist=( $(echo ${{blacklist_in}}) )

stream="{stream}"
if [ -n "$stream" ] ; then
    stream=carbon
fi

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep $search_string | grep $stream)

bl_len=${{#blacklist[@]}}
for (( i = 0; i < ${{bl_len}}; i++ )); do
    jobs="$(echo "$jobs" | grep -v ${{blacklist[$i]}} )"
done
# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g' > {jobs-filename}

