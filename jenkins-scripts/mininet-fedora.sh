#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# allow 6640 to be used with OVS if needed
semanage port -a -t openvswitch_port_t -p 6640

# make sure the firewall is stopped
service iptables stop

# stop firewall
systemctl stop firewalld

# vim: sw=2 ts=2 sts=2 et :
