#!/bin/bash
# vim: sw=2 ts=2 sts=2 et :

yum clean all

# disable the firewall
/bin/bash ./disable_firewall.sh

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF
