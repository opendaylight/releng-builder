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
git checkout -b 2.2.1 2.2.1
git apply -p0 < ../newOptions.patch
cd ./util
./install.sh -nfv

