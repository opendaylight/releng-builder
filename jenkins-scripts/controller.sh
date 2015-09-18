#!/bin/bash

# disable the firewall
/bin/bash ./disable_firewall.sh

# install sshpass
yum install -y sshpass

# vim: sw=2 ts=2 sts=2 et :
# Installation of Hbase
mkdir /tmp/Hbase
cd /tmp/Hbase

wget --no-verbose https://archive.apache.org/dist/hbase/hbase-0.94.15/hbase-0.94.15.tar.gz

echo "Installing the Hbase Server..."
tar -xvf hbase*.tar.gz

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF
