#!/bin/sh

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# Add 'hostname' into /etc/hosts during node spinup time to avoid sudo returning
# an 'unable to resolve host' message or some Java API's returning an unknown
# host exception. The workaround on adding "myhostname" into /etc/nss-switch.conf
# does not work on Ubuntu flavours.
sed -i "/127.0.0.1/s/$/\t$(hostname)/" /etc/hosts

# Do the final install of OVS that the has to be done at boot time for
# some reason due to how the snapshots keep behaving.
dpkg --install /root/openvswitch-datapath-dkms* && \
dpkg --install /root/openvswitch-common* && \
dpkg --install /root/openvswitch-switch*

# add user jenkins to docker group
/usr/sbin/usermod -a -G docker jenkins

# pull docker images
docker pull alagalah/odlpoc_ovs230

# vim: sw=2 ts=2 sts=2 et :
