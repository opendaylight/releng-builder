#!/bin/sh

# Script to delete Jenkins jobs by searching a string.
#
#   Usage: ./delete-jobs <search_string>
#
# For example: *-validate-autorelease-*
#     ./delete-jobs validate-autorelease


search_string=$1

printf "Enter system (sandbox|releng): "
read -r system
printf "Enter username: "
read -r username
printf "Enter api_token: "
read -r password

echo "$username:$password"

wget -O jenkins-jobs.xml "https://jenkins.opendaylight.org/$system/api/xml"

jobs=$(xmlstarlet sel -t -m '//hudson/job' \
                     -n -v 'name' jenkins-jobs.xml | \
      grep "$search_string")

for job in $(echo "$jobs" | tr "\n" " "); do
    echo "Deleting $job"
    curl -X POST "https://$username:$password@jenkins.opendaylight.org/$system/job/${job}/doDelete"
done
