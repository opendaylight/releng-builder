#!/bin/bash

#######################
# Create Jenkins User #
#######################

DISTRO=$(logname)
useradd -m jenkins
mkdir /home/jenkins/.ssh
mkdir /w
cp -r /home/${DISTRO}/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh /w
