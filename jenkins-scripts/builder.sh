#!/bin/bash
# vim: sw=2 ts=2 sts=2 et :

yum clean all

#
# Integration/Packaging
#

# Install software for building RPMs
yum install -y fedora-packager

# Install software for building docs
yum install -y libxslt-devel

# disable the firewall
/bin/bash ./disable_firewall.sh

# install sshpass
yum install -y sshpass

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# install crudini command line tool for editing config files
yum install -y crudini
