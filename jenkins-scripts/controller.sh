#!/bin/bash

# disable the firewall
service iptables stop

# install sshpass
yum install -y sshpass

# vim: sw=2 ts=2 sts=2 et :

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: /sbin/iptables
EOF
