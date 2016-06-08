#!/bin/bash

#######################
# Create Jenkins User #
#######################

OS=$(facter operatingsystem | tr '[:upper:]' '[:lower:]')

# Determine if we need to add jenkins to the docker group
grep -q docker /etc/group
if [ "$?" == '0' ]
then
  GROUP='-G docker'
else
  GROUP=''
fi

useradd -m ${GROUP} -s /bin/bash jenkins
mkdir /home/jenkins/.ssh
mkdir /w
cp -r /home/${OS}/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
# Generate ssh key for use by Robot jobs
echo -e 'y\n' | ssh-keygen -N "" -f /home/jenkins/.ssh/id_rsa -t rsa
chown -R jenkins:jenkins /home/jenkins/.ssh /w
