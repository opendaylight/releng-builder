#!/bin/bash

/usr/sbin/usermod -a -G docker jenkins

# stop firewall
systemctl stop firewalld

# restart docker daemon - needed after firewalld stop
systemctl restart docker

# vim: sw=2 ts=2 sts=2 et :

