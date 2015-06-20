#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# make sure the firewall is stopped
service iptables stop

# disable vm security
/usr/sbin/setenforce 0
systemctl disable firewalld
systemctl stop firewalld

# vim: sw=2 ts=2 sts=2 et :
