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
yum install -q -y git perl-{XML-XPath,Digest-SHA}

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

# add in mininet, openvswitch, and netopeer
yum install -q -y netopeer-server-sl CPqD-ofsoftswitch13 mininet \
    telnet openvswitch

# we need semanage installed for some of the next bit
yum install -q -y policycoreutils-python

# netconf / netopeer needs some special modifications to ssh
semanage port -a -t ssh_port_t -p tcp '830'

# The default /etc/ssh/sshd_config doesn't actually specify a port as such
# we need to specify both 22 as well as 830 along with the netconf
# subsystem
echo << EOSSH >> /etc/ssh/sshd_config

# Added for netconf / netopeer testing
Port 22
Port 830
Subsystem netconf /usr/bin/netopeer-server-sl
EOSSH

# cbench installation for running openflow performance tests

OF_DIR=$HOME/openflow  # Directory that contains OpenFlow code
OFLOPS_DIR=$HOME/oflops  # Directory that contains oflops repo

yum install -q -y net-snmp-devel libpcap-devel autoconf make automake libtool libconfig-devel

git clone git://gitosis.stanford.edu/openflow.git $OF_DIR &> /dev/null
git clone https://github.com/andi-bigswitch/oflops.git $OFLOPS_DIR &> /dev/null

cd $OFLOPS_DIR
./boot.sh &> /dev/null
./configure --with-openflow-src-dir=$OF_DIR &> /dev/null
make &> /dev/null
make install &> /dev/null
