#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

yum clean all
# Add the ODL yum repo (not needed for java nodes, but useful for
# potential later layers)
yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm

# Make sure the system is fully up to date
yum update -q -y

# Add in git (needed for most everything) and XML-XPath as it is useful
# for doing CLI based CML parsing of POM files
yum install -q -y git perl-XML-XPath

# install all available openjdk-devel sets
yum install -q -y 'java-*-openjdk-devel'

# we currently use Java7 (aka java-1.7.0-openjdk) as our standard make
# sure that this is the java that alternatives is pointing to, dynamic
# spin-up scripts can switch to any of the current JREs installed if
# needed
alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc
