#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# Do the final install of OVS that the has to be done at boot time for
# some reason due to how the snapshots keep behaving.
dpkg --install /root/openvswitch-datapath-dkms* && \
dpkg --install /root/openvswitch-{common,switch}*

# add user jenkins to docker group
/usr/sbin/usermod -a -G docker jenkins

# pull docker images
docker pull alagalah/odlpoc_ovs230

# vim: sw=2 ts=2 sts=2 et :
