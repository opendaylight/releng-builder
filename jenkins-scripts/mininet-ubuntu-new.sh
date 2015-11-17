#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# disable the firewall
/bin/bash ./disable_firewall.sh
