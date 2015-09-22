#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
apt-get upgrade -y --force-yes -qq

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

# Install mininet
# apt-get install -y --force-yes -qq mininet

# Install mininet with OF13 patch
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

# Install CPqD
apt-get install -y --force-yes -qq build-essential cmake flex
apt-get install -y --force-yes -qq libpcre++-dev libxerces-c-dev libpcap-dev libboost-all-dev

cd /tmp
wget -nc http://de.archive.ubuntu.com/ubuntu/pool/main/b/bison/bison_2.5.dfsg-2.1_amd64.deb \
         http://de.archive.ubuntu.com/ubuntu/pool/main/b/bison/libbison-dev_2.5.dfsg-2.1_amd64.deb

dpkg -i bison_2.5.dfsg-2.1_amd64.deb libbison-dev_2.5.dfsg-2.1_amd64.deb
rm bison_2.5.dfsg-2.1_amd64.deb libbison-dev_2.5.dfsg-2.1_amd64.deb

wget -nc http://www.nbee.org/download/nbeesrc-jan-10-2013.zip
unzip nbeesrc-jan-10-2013.zip
cd nbeesrc-jan-10-2013/src
cmake .
make
cp ../bin/libn*.so /usr/local/lib
ldconfig
cp -R ../include/* /usr/include/
cd ../..

git clone https://github.com/CPqD/ofsoftswitch13.git
cd ofsoftswitch13
./boot.sh
./configure
make
make install
cd ..

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