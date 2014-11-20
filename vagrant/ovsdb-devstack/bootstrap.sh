#!/bin/bash

# enable enforcing mode from the very start
setenforce enforcing

# configure system for enforcing mode on next boot
sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

yum clean all
yum update -y
yum install -q -y deltarpm python{,-{crypto,devel,lxml,setuptools}} \
	@development-tools {lib{xml2,xslt,ffi},openssl}-devel \
	java git sudo

# figure out what the latest kernel installed is and switch to it
# NOTE: This is done like this becase the Rackspace F20 images are using
# extlinux / syslinux and don't switch to the newest kernel on update
NEWKERNEL=`rpm -qa | grep kernel-3 | sort -r | head -1 | cut -c 8-`
BOOTLABEL=`grep ${NEWKERNEL} /boot/extlinux.conf | grep LABEL | cut -c 7-`
sed -i "s/ONTIMEOUT linux/ONTIMEOUT ${BOOTLABEL}/" /boot/extlinux.conf

if [ ! -f /etc/udev/rules.d/80-net-setup-link.rules ]; then
    ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"
