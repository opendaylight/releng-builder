#!/bin/bash

# Format and mount rackspace data disk
mkfs -t ext3 /dev/xvde1
mkdir /opt/jenkins/workspace
mount /dev/xvde1 /opt/jenkins/workspace
chown jenkins:jenkins /opt/jenkins/workspace
