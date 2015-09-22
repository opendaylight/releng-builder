#!/bin/bash

# add user jenkins to docker group
/usr/sbin/usermod -a -G docker jenkins

# pull docker images
docker pull alagalah/odlpoc_ovs230

# vim: sw=2 ts=2 sts=2 et :

