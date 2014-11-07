#!/bin/bash

# vim: ts=4 sw=4 sts=4 et :

# Handle the occurance where SELINUX is actually disabled
if [ `grep SELINUX=permissive /etc/selinux/config` ]; then
    # enable enforcing mode from the very start
    setenforce enforcing

    # configure system for enforcing mode on next boot
    sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
else
    sed -i 's/SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
    touch /.autorelabel

    echo "*******************************************"
    echo "** SYSTEM REQUIRES A RESTART FOR SELINUX **"
    echo "*******************************************"
fi

yum clean all -q
yum update -y -q
