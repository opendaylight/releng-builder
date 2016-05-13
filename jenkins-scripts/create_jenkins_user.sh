#!/bin/bash

#######################
# Create Jenkins User #
#######################

OS=`facter operatingsystem | tr '[:upper:]' '[:lower:]'`

useradd -m jenkins
mkdir /home/jenkins/.ssh
mkdir /w
cp -r /home/${OS}/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh /w
