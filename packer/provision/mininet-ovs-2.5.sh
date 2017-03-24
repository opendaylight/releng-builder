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

# remove all force-yes with --allow*
echo '---> Install OpenVSwitch 2.5.0'
apt-get update -y --force-yes
apt-get install -y --force-yes openvswitch-switch openvswitch-vtep

echo '---> Installing mininet'
apt-get install -y --force-yes mininet

echo '---> Installing build pre-requisites'
apt-get install -y --force-yes build-essential snmp libsnmp-dev snmpd libpcap-dev \
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
apt-get install -y --force-yes exabgp

echo '---> All Python package installation should happen in virtualenv'
apt-get install -y --force-yes python-virtualenv python-pip

# Install vlan for vlan based tests in VTN suites
apt-get install -y --force-yes -qq vlan

# Install netaddr package which is needed by some custom mininet topologies
apt-get install -y --force-yes -qq python-netaddr
