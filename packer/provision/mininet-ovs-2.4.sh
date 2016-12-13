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

echo '---> Install OpenVSwitch 2.4.0'
wget -c http://openvswitch.org/releases/openvswitch-2.4.0.tar.gz
tar -zxvf openvswitch-2.4.0.tar.gz
cd openvswitch-2.4.0

#CONFIGURATION 

./configure --prefix=/usr --with-linux=/lib/modules/`uname -r`/build

#MAKE & MAKE INSTALL

make -j4
make install
make modules_install

#REMOVE THE KERNEL MODULE

rmmod openvswitch

#HANDLE DEPENDENCY DESCRIPTIONS FOR LOADABLE KERNEL MODULES

depmod -a

#CHECK THE VERSION OF VSWITCH

ovs-vswitchd --version

cd ..

echo '---> Installing mininet 2.2.2'
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.2 2.2.2
cd ..
mininet/util/install.sh -nf

echo '---> Installing MT-Cbench'
apt-get install -y --force-yes build-essential snmp libsnmp-dev snmpd libpcap-dev \
autoconf make automake libtool libconfig-dev libssl-dev libffi-dev libssl-doc pkg-config
git clone https://github.com/intracom-telecom-sdn/mtcbench.git
mtcbench/build_mtcbench.sh
cp mtcbench/oflops/cbench/cbench /usr/local/bin/

echo '---> Installing exabgp'
apt-get install -y --force-yes exabgp

echo '---> All Python package installation should happen in virtualenv'
apt-get install -y --force-yes python-virtualenv python-pip
