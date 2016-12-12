#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# Install minimal python requirements to get virtualenv going
# Additional python dependencies should be installed via JJB configuration
# inside project jobs using a virtualenv setup.
yum install -y python-{devel,setuptools,virtualenv} @development

# Install dependencies for robotframework and robotframework-sshlibrary
# installed elsewhere
yum install -y yum-utils unzip sshuttle nc libffi-devel openssl-devel

# Install dependencies for matplotlib library used in longevity framework
yum install -y libpng-devel freetype-devel python-matplotlib

# install crudini command line tool for editing config files
yum install -y crudini

# Install dependency for postgres database used in storing performance plot results
yum -y install postgresql-devel

################################
# LISPFLOWMAPPING REQUIREMENTS #
################################

# Needed for pyangbind
yum install -y libxml2-devel libxslt-devel

# Install `udpreplay` to be used for (lispflowmapping) performance tests
yum install -y libpcap-devel boost-devel
git clone https://github.com/ska-sa/udpreplay.git
cd udpreplay
./bootstrap.sh
./configure
make &> /dev/null && cp udpreplay /usr/local/bin

#####################
# DLUX requirements #
#####################

#  - Xvfb: Display manager in RAM
#
# Note: The end goal will be to test with multiple browser (Firefox, Chrome)
#       Chrome need a other library named chromedriver so let start with
#       one already supported with selenium.
yum install -y firefox xorg-x11-server-Xvfb
