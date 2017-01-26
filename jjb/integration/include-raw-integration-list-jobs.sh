#!/bin/bash

# Script to filter Jenkins CSIT jobs against a blacklist
# output: newline & comma-separated list to terminal
#
#   Usage: ./include-raw-integration-list-jobs.sh "space separated list" <stream>
#
# For example: list jobs not matching "longevity" or "gate" in stream carbon
#     ./include-raw-integration-list-jobs.sh "longevity gate" carbon

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

bl_len=${#blacklist[@]}
for (( i = 0; i < ${bl_len}; i++ )); do
    jobs="$(echo "$jobs" | grep -v ${blacklist[$i]} )"
done
# output as comma-separated list with 8 spaces before each item
echo $jobs | sed 's: :,\n:g' | sed 's:^\(.*\):        \1:g'

