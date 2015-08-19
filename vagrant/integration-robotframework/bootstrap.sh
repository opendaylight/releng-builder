#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

yum clean all
# Add the ODL yum repo
yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
yum update -q -y

yum install -q -y java-1.7.0-openjdk-devel git perl-XML-XPath

# The following are known requirements for our robotframework environments
yum install -q -y python-{devel,importlib,requests,setuptools,virtualenv,docker-py} \
    robotframework{,-{httplibrary,requests,sshlibrary}}

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc
