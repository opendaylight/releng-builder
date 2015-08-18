#!/bin/bash

yum clean all
# Add the ODL yum repo
yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
yum update -q -y

yum install -q -y java-1.7.0-openjdk-devel docker-io supervisor git python-{devel,importlib,requests,setuptools,virtualenv,docker-py} \
        robotframework{,-{httplibrary,requests,sshlibrary}}

systemctl enable docker.service

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"
