#!/bin/bash

yum clean all
yum install -y unzip
yum install -y python-netaddr

# disable firewall rules
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
