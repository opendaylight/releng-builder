#!/bin/bash

yum clean all
yum install -y -q unzip python-netaddr @development
yum remove -y robotframework-{sshlibrary,requests}

## install Latest Robot Framewrok from source
cd /tmp
wget https://pypi.python.org/packages/source/r/robotframework/robotframework-2.9a1.tar.gz > /dev/null 2>&1
tar -xvf robotframework-2.9a1.tar.gz > /dev/null 2>&1
cd robotframework-2.9a1
python setup.py install > /dev/null 2>&1

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

## install Latest Robot Framework Selenium2Library from source
cd /tmp
wget https://pypi.python.org/packages/source/r/robotframework-selenium2library/robotframework-selenium2library-1.7.1.tar.gz > /dev/null 2>&1
tar -xvf robotframework-selenium2library-1.7.1.tar.gz > /dev/null 2>&1
cd robotframework-selenium2library-1.7.1
python setup.py install > /dev/null 2>&1

## Install netcat & docker-py
yum install -y -q nc python-docker-py

# make sure the firewall is stopped
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
