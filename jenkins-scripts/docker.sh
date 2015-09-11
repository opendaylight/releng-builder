#!/bin/bash

/usr/sbin/usermod -a -G docker jenkins

# stop firewall
systemctl stop firewalld

# vim: sw=2 ts=2 sts=2 et :

