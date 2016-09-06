#!/bin/bash

set -e

echo "---> Setting up controller IP"
CONTROLLER_IP=`facter ipaddress`
echo "CONTROLLER_IP=${CONTROLLER_IP}" > env.properties

echo "---> Loading OVS kernel module"
sudo /usr/sbin/modprobe openvswitch

echo "---> Verifying OVS kernel module loaded"
/usr/sbin/lsmod | /usr/bin/grep openvswitch

