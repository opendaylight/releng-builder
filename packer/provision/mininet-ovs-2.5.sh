#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# Ensure that necessary variables are set to enable noninteractive mode in
# commands.
export DEBIAN_FRONTEND=noninteractive

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

echo '---> Install OpenVSwitch 2.5.0'
add-apt-repository -y ppa:sgauthier/openvswitch-dpdk
apt-get-update
apt-get install -y --force-yes -qq openvswitch-switch

echo '---> Installing mininet 2.2.2'
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.2 2.2.2
cd ..
mininet/util/install.sh -nf

echo '---> Installing cbench for openflow performance tests'
OF_DIR=$HOME/openflow  # Directory that contains OpenFlow code
OFLOPS_DIR=$HOME/oflops  # Directory that contains oflops repo

apt-get install -y --force-yes -qq libsnmp-dev libpcap-dev libconfig-dev

git clone git://gitosis.stanford.edu/openflow.git $OF_DIR
git clone https://github.com/andi-bigswitch/oflops.git $OFLOPS_DIR

cd $OFLOPS_DIR
./boot.sh
./configure --with-openflow-src-dir=$OF_DIR
make
make install

echo '---> Installing exabgp'
apt-get install -y --force-yes -qq exabgp

echo '---> All Python package installation should happen in virtualenv'
apt-get install -y --force-yes -qq python-virtualenv python-pip
