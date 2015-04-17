#!/bin/bash

# disable the firewall
service iptables stop

# install sshpass
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/sshpass-1.05-1.el6.x86_64.rpm
yum install -y sshpass-1.05-1.el6.x86_64.rpm

# vim: sw=2 ts=2 sts=2 et :
