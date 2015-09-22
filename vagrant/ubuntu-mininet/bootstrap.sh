#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
apt-get upgrade -y --force-yes -qq

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

# Install mininet
apt-get install -y --force-yes -qq mininet
