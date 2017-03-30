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

echo '---> Install mininet with OF13 patch'
cd /tmp
cat > newOptions.patch <<EOF
--- mininet/node.py     2014-09-12 13:48:03.165628683 +0100
+++ mininet/node.py     2014-09-12 13:50:39.021630236 +0100
@@ -952,6 +952,10 @@
            datapath: userspace or kernel mode (kernel|user)"""
         Switch.__init__( self, name, **params )
         self.failMode = failMode
+        protKey = 'protocols'
+        if self.params and protKey in self.params:
+               print 'have protcol params!'
+               self.opts += protKey + '=' + self.params[protKey]
         self.datapath = datapath

     @classmethod
@@ -1027,8 +1031,9 @@
         if self.datapath == 'user':
             self.cmd( 'ovs-vsctl set bridge', self,'datapath_type=netdev' )
         int( self.dpid, 16 ) # DPID must be a hex string
+        print 'OVSswitch opts: ',self.opts
         self.cmd( 'ovs-vsctl -- set Bridge', self,
-                  'other_config:datapath-id=' + self.dpid )
+                  self.opts+' other_config:datapath-id=' + self.dpid )
         self.cmd( 'ovs-vsctl set-fail-mode', self, self.failMode )
         for intf in self.intfList():
             if not intf.IP():
EOF

git clone git://github.com/mininet/mininet
cd mininet/
git checkout -b 2.1.0 2.1.0
git apply -p0 < ../newOptions.patch
cd ./util
./install.sh -nfv

echo '---> Installing cbench installation for running openflow performance tests'
OF_DIR=$HOME/openflow  # Directory that contains OpenFlow code
OFLOPS_DIR=$HOME/oflops  # Directory that contains oflops repo

apt-get install -y --force-yes libsnmp-dev libpcap-dev libconfig-dev

git clone git://gitosis.stanford.edu/openflow.git $OF_DIR
git clone https://github.com/andi-bigswitch/oflops.git $OFLOPS_DIR

cd $OFLOPS_DIR
./boot.sh
./configure --with-openflow-src-dir=$OF_DIR
make
make install

echo '---> Installing vlan for vlan based tests in VTN suites'
apt-get install -y --force-yes vlan

echo '---> All Python package installation should happen in virtualenv'
apt-get install -y --force-yes python-virtualenv python-pip

# Install netaddr package which is needed by some custom mininet topologies
apt-get install -y --force-yes -qq python-netaddr
