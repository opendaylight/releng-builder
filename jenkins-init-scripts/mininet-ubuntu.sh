#!/bin/sh

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# disable the firewall
/bin/bash ./disable_firewall.sh

# Add 'hostname' into /etc/hosts during node spinup time to avoid sudo returning
# an 'unable to resolve host' message or some Java API's returning an unknown
# host exception. The workaround on adding "myhostname" into /etc/nss-switch.conf
# does not work on Ubuntu flavours.
sed -i "/127.0.0.1/s/$/\t$(hostname)/" /etc/hosts
