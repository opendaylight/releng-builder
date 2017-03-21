#!/bin/bash

#######################
# Create Jenkins User #
#######################

# Default facter binary get removed when puppet4 is installed
# This requires us to source puppet-agent.sh to use the version
# of facter shipped with puppet4
if [ -f "/etc/profile.d/puppet-agent.sh" ]; then
    source "/etc/profile.d/puppet-agent.sh"
fi

OS=$(facter operatingsystem | tr '[:upper:]' '[:lower:]')

useradd -m -s /bin/bash jenkins

# Check if docker group exists
if grep -q docker /etc/group
then
    # Add jenkins user to docker group
    usermod -a -G docker jenkins
fi

# Check if mock group exists
if grep -q mock /etc/group
then
    # Add jenkins user to mock group so they can build Int/Pack's RPMs
    usermod -a -G mock jenkins
fi

mkdir /home/jenkins/.ssh
mkdir /w
cp -r "/home/${OS}/.ssh/authorized_keys" /home/jenkins/.ssh/authorized_keys
# Generate ssh key for use by Robot jobs
echo -e 'y\n' | ssh-keygen -N "" -f /home/jenkins/.ssh/id_rsa -t rsa
chown -R jenkins:jenkins /home/jenkins/.ssh /w
chmod 700 /home/jenkins/.ssh
