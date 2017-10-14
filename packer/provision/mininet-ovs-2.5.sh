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

echo '---> Install OpenVSwitch 2.5.0'
apt-get update -m
apt-get install openvswitch-switch openvswitch-vtep

# Temporary workaround required to bring up OVS
# post-install without which OVS daemon exits.
service openvswitch-switch restart
# Verify the OVS service status
service openvswitch-switch status

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
