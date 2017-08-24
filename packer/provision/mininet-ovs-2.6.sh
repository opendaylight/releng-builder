#!/bin/bash -x

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

echo '---> Install OpenVSwitch 2.6.1'
apt-get update -m
apt-get install dh-autoreconf debhelper autoconf automake libssl-dev pkg-config bzip2 openssl python-all procps python-qt4 python-zopeinterface python-twisted-conch
mkdir /tmp/ovs-26
cd /tmp/ovs-26
pwd
wget http://openvswitch.org/releases/openvswitch-2.6.1.tar.gz
tar -xzvf openvswitch-2.6.1.tar.gz
cd openvswitch-2.6.1
DEB_BUILD_OPTIONS='parallel=8 nocheck' fakeroot debian/rules binary
cd /tmp/ovs-26
dpkg -i openvswitch-common_2.6.1-1_amd64.deb openvswitch-switch_2.6.1-1_amd64.deb python-openvswitch_2.6.1-1_all.deb openvswitch-vtep_2.6.1-1_amd64.deb
systemctl unmask openvswitch-switch
service openvswitch-switch start
service openvswitch-vtep start
echo '---> Waiting 15 secs for services to start'
sleep 15
ovs-vsctl --version
ovs-vsctl show
ps -elf|grep ovs
ps -elf|grep vtep
echo '---> Finished installing OpenVSwitch 2.6.1'

echo '---> Installing mininet'
apt-get install mininet

echo '---> Installing build pre-requisites'
apt-get install build-essential snmp libsnmp-dev snmpd libpcap-dev \
autoconf make automake libtool libconfig-dev libssl-dev libffi-dev libssl-doc pkg-config

git clone https://github.com/intracom-telecom-sdn/mtcbench.git
mtcbench/deploy/docker/provision.sh
# TODO: remove workaround for build issue with mtcbench
# when mtcbench dependency build correctly
# https://github.com/intracom-telecom-sdn/mtcbench/issues/10
mtcbench/build_mtcbench.sh || true
cd mtcbench/oflops/cbench
make
cp cbench /usr/local/bin/

echo '---> Installing exabgp'
apt-get install exabgp

# Install vlan for vlan based tests in VTN suites
apt-get install vlan

# Install netaddr package which is needed by some custom mininet topologies
apt-get install python-netaddr

# Check out quagga , compile and install for router functionalities
echo "Installing the Quagga..."
mkdir -p /tmp/build_quagga
cd /tmp/build_quagga
git clone https://github.com/6WIND/zrpcd.git
cd zrpcd
git checkout 20170731
chmod a+x /tmp/build_quagga/zrpcd/pkgsrc/dev_compile_script.sh
/tmp/build_quagga/zrpcd/pkgsrc/dev_compile_script.sh -d -b -t

# Removing the build_quagga folder
rm -rf /tmp/build_quagga/
