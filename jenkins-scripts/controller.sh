#!/bin/bash

# disable the firewall
service iptables stop

# install sshpass
yum install -y sshpass

# vim: sw=2 ts=2 sts=2 et :
