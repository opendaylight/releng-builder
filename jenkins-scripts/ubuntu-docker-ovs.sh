#!/bin/bash

# Do the final install of OVS that the has to be done at boot time for
# some reason due to how the snapshots keep behaving.
dpkg --install /root/openvswitch-datapath-dkms* && \
dpkg --install /root/openvswitch-{common,switch}*

# add user jenkins to docker group
/usr/sbin/usermod -a -G docker jenkins

# pull docker images
docker pull alagalah/odlpoc_ovs230

# vim: sw=2 ts=2 sts=2 et :

