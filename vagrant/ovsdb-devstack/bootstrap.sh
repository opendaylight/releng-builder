#!/bin/bash

# enable enforcing mode from the very start
setenforce enforcing

# configure system for enforcing mode on next boot
sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

yum clean all
yum update -y
yum install -q -y deltarpm python python-crypto python-devel python-lxml python-setuptools @development-tools libxml2-devel libxslt-devel libffi-devel
yum install -q -y java git sudo openssl-devel

if [ ! -f /etc/udev/rules.d/80-net-setup-link.rules ]; then
    ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"
