#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# update os
yum clean all
yum update -q -y

# install basic stuff
yum install -q -y java-1.7.0-openjdk-devel git

# install openvswitch
yum install -q -y openvswitch
systemctl start openvswitch.service

# install mininet
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.1 2.2.1
cd ..
mininet/util/install.sh -nf

# changing user prompt to >
# we should adjust our tests for not requiring this
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

