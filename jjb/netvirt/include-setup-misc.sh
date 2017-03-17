#!/bin/bash

# Default facter binary get removed when puppet4 is installed
# This requires us to source puppet-agent.sh to use the version
# of facter shipped with puppet4
if [ -f "/etc/profile.d/puppet-agent.sh" ]; then
    source "/etc/profile.d/puppet-agent.sh"
fi

# Add puppetlabs bin to $PATH
if [ -f "/etc/profile.d/puppet-agent.sh" ]; then
    source "/etc/profile.d/puppet-agent.sh"
fi

set -e

echo "---> Setting up controller IP"
CONTROLLER_IP=$(facter ipaddress)
echo "CONTROLLER_IP=${CONTROLLER_IP}" > env.properties

echo "---> Loading OVS kernel module"
sudo /usr/sbin/modprobe openvswitch

echo "---> Verifying OVS kernel module loaded"
/usr/sbin/lsmod | /usr/bin/grep openvswitch
