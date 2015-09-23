#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

yum clean all
# Add the ODL yum repo
yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
yum update -q -y

# Install minimal python requirements to get virtualenv going
# Additional python dependencies should be installed via JJB configuration
# inside project jobs using a virtualenv setup.
yum install -q -y python-{devel,setuptools,virtualenv}

# Install `udpreplay` to be used for (lispflowmapping) performance tests
yum install -q -y libpcap-devel boost-devel
git clone https://github.com/ska-sa/udpreplay.git &> /dev/null
cd udpreplay
make &> /dev/null && cp udpreplay /usr/local/bin

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc
