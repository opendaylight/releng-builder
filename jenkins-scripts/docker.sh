#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: /sbin/ifconfig
EOF

/usr/sbin/usermod -a -G docker jenkins

# stop firewall
systemctl stop firewalld

# restart docker daemon - needed after firewalld stop
systemctl restart docker

# vim: sw=2 ts=2 sts=2 et :

