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
export OVS_HOME=`pwd`

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

echo '---> Install OVS 2.4 Python module'
wget -c https://pypi.python.org/packages/2f/8a/358cad389613865ee255c7540f9ea2c2f98376c2d9cd723f5cf30390d928/ovs-2.4.0.tar.gz#md5=9097ced87a88e67fbc3d4b92c16e6b71
tar -zxvf ovs-2.4.0.tar.gz
cd ovs-2.4.0
mkdir -p /var/run/openvswitch/
python setup.py install

cd ..

echo '---> Congfigure OVS 2.4 TOR Emulation'

echo '---> Stop OVS'
killall -9 ovs-vtep
killall -9 ovs-vswitchd
killall -9 ovsdb-server

# Configure the TOR 
rm /etc/openvswitch/ovs.db
rm /etc/openvswitch/vtep.db
ovsdb-tool create /etc/openvswitch/ovs.db $OVS_HOME/vswitchd/vswitch.ovsschema
ovsdb-tool create /etc/openvswitch/vtep.db $OVS_HOME/vtep/vtep.ovsschema
sleep 1
ovsdb-server --pidfile --detach --log-file --remote punix:/usr/var/run/openvswitch/db.sock\
--remote=db:hardware_vtep,Global,managers /etc/openvswitch/ovs.db /etc/openvswitch/vtep.db
ovs-vsctl --no-wait init
ovs-vswitchd --pidfile --detach
ovs-vsctl add-br br0
sleep 1
ovs-vsctl show
vtep-ctl add-ps br0
vtep-ctl set Physical_Switch br0 tunnel_ips=12.0.0.11
sleep 1
$OVS_HOME/vtep/ovs-vtep --log-file=/var/log/openvswitch/ovs-vtep.log\
--pidfile=/var/run/openvswitch/ovs-vtep.pid\
--detach br0

