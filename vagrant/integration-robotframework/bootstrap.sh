#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

yum clean all
yum update -q -y

# Install minimal python requirements to get virtualenv going
# Additional python dependencies should be installed via JJB configuration
# inside project jobs using a virtualenv setup.
yum install -q -y python-{devel,setuptools,virtualenv}

# Install the `time` binary
yum install -q -y time

# Install `udpreplay` to be used for (lispflowmapping) performance tests
yum install -q -y @development libpcap-devel boost-devel
git clone -q https://github.com/ska-sa/udpreplay.git
cd udpreplay
make &> /dev/null && cp udpreplay /usr/local/bin

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc
