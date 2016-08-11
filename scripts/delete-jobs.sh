#!/bin/bash

# Script to delete Jenkins jobs by searching a string.
#
#   Usage: ./rename-jobs <search_string>
#
# For example: *-validate-autorelease-*
#     ./delete-jobs validate-autorelease


search_string=$1

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
    echo "Deleting $job"
    curl -X POST "https://$username:$password@jenkins.opendaylight.org/$system/job/${job}/doDelete"
done
