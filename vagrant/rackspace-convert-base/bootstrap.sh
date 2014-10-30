#!/bin/bash

# enable enforcing mode from the very start
setenforce enforcing

# configure system for enforcing mode on next boot
sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

yum clean all
yum update -y
