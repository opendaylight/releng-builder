#!/bin/bash

# Script to rename Jenkins jobs for a specific branch to a new_branch
# For example: aaa-merge-master > aaa-merge-beryllium
#   Usage: ./rename-jobs <branch> <new_branch>

branch=$1
new_branch=$2

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
      grep ${branch}`

for job in `echo $jobs | tr "\n" " "`; do
    new_job=`echo $job | sed -e "s/${branch}/${new_branch}/"`
    echo "Renaming $job to $new_job"
    curl --data "newName=${new_job}" "https://$username:$password@jenkins.opendaylight.org/$system/job/${job}/doRename"
done


