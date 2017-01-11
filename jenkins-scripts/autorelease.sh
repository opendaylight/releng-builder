#!/bin/bash

# Temporary measure until patch Ie03aa8a6364076690e5963b422c17e4feb70a6e2
# is merged and images updated.
yum install -y git-review

# Format and mount rackspace data disk
mkfs -t ext3 /dev/xvde1
mkdir /w/workspace
mount /dev/xvde1 /w/workspace
chown jenkins:jenkins /w/workspace
