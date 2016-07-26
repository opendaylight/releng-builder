#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# disable the firewall
/bin/bash ./disable_firewall.sh

# Make sure apt-get database is up-to-date
apt-get update -y --force-yes -qq

# Install vlan for vlan based tests in VTN suites
apt-get install -y --force-yes -qq vlan

# Install netaddr package which is needed by some custom mininet topologies
apt-get install -y --force-yes -qq python-netaddr
