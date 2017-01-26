#!/bin/bash

# Script to filter Jenkins CSIT jobs against a blacklist
# output: newline & comma-separated list to terminal
#
#   Usage: ./list-jobs "space separated list" <stream>
#
# For example: list jobs not matching "longevity" or "gate" in stream carbon
#     ./list-jobs "longevity gate" carbon

search_string=csit
system=releng
blacklist_in="longevity gate"
if [ -n "$1" ] ; then 
    blacklist_in="$1"
fi
blacklist=( $(echo ${blacklist_in}) )

stream=carbon
if [ -n "$2" ] ; then 
    stream=$2
fi

wget --quiet -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml
jobs=$(xmlstarlet sel -t -m '//hudson/job' \
    -n -v 'name' jenkins-jobs.xml | grep ${search_string} | grep ${stream})
#echo "Total of $(echo "$jobs" | wc -l) \"${search_string}\" jobs found in stream=${stream}"

bl_len=${#blacklist[@]}
for (( i = 0; i < ${bl_len}; i++ )); do
    #echo "removing jobs for: ${blacklist[$i]}"
    jobs="$(echo "$jobs" | grep -v ${blacklist[$i]} )"
    #echo "$(echo "$jobs" | wc -l ) jobs remaining after removing ${blacklist[$i]}"
done
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g'

