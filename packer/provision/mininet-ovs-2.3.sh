#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# Ensure that necessary variables are set to enable noninteractive mode in
# commands.
export DEBIAN_FRONTEND=noninteractive

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

echo '---> Install OpenVSwitch 2.3.1'
add-apt-repository -y ppa:vshn/openvswitch
apt-get update -y --force-yes
apt-get install -y --force-yes openvswitch-switch

echo '---> Installing mininet 2.2.1'
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.1 2.2.1
cd ..
mininet/util/install.sh -nf

echo '---> Installing cbench for openflow performance tests'
OF_DIR=$HOME/openflow  # Directory that contains OpenFlow code
OFLOPS_DIR=$HOME/oflops  # Directory that contains oflops repo

apt-get install -y --force-yes libsnmp-dev libpcap-dev libconfig-dev

git clone https://github.com/andi-bigswitch/oflops.git $OFLOPS_DIR

cd $OFLOPS_DIR
./boot.sh
./configure --with-openflow-src-dir=$OF_DIR
make
make install

echo '---> Installing exabgp'
apt-get install -y --force-yes exabgp

echo '---> All Python package installation should happen in virtualenv'
apt-get install -y --force-yes python-virtualenv python-pip

# Install vlan for vlan based tests in VTN suites
apt-get install -y --force-yes -qq vlan

# Install netaddr package which is needed by some custom mininet topologies
apt-get install -y --force-yes -qq python-netaddr
