#!/bin/bash

# Script to rename Jenkins jobs by searching and replacing a string with a new
# string.
#
#   Usage: ./rename-jobs <search_string> <replace_string>
#
# For example: aaa-merge-master > aaa-merge-beryllium
#     ./rename-jobs master beryllium


search_string=$1
replace_string=$2

echo -n "Enter system (sandbox|releng): "
read system
echo -n "Enter username: "
read username
echo -n "Enter api_token: "
read password

echo $username:$password

wget -O jenkins-jobs.xml https://jenkins.opendaylight.org/$system/api/xml

jobs=`xmlstarlet sel -t -m '//hudson/job' \
                     -n -v 'name' jenkins-jobs.xml | \
      grep ${search_string}`

for job in `echo $jobs | tr "\n" " "`; do
    new_job=`echo $job | sed -e "s/${search_string}/${replace_string}/"`
    echo "Renaming $job to $new_job"
    curl --data "newName=${new_job}" "https://$username:$password@jenkins.opendaylight.org/$system/job/${job}/doRename"
done
