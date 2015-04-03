#!/bin/bash

yum clean all
yum install -y unzip
yum install -y python-netaddr
yum install -y python-devel
yum groupinstall -y "Development Tools"

## install Latest Robot SSHLibrary from source
cd /tmp
wget http://pypi.python.org/packages/source/r/robotframework-sshlibrary/robotframework-sshlibrary-2.1.1.tar.gz > /dev/null 2>&1
tar -xvf robotframework-sshlibrary-2.1.1.tar.gz > /dev/null 2>&1
cd robotframework-sshlibrary-2.1.1
python setup.py install > /dev/null 2>&1

## install Latest Robot RequestsLibrary from source
cd /tmp
wget https://github.com/bulkan/robotframework-requests/archive/v0.3.8.tar.gz > /dev/null 2>&1
tar -xvf v0.3.8.tar.gz > /dev/null 2>&1
cd robotframework-requests-0.3.8/
python setup.py install > /dev/null 2>&1

# disable firewall rules
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
