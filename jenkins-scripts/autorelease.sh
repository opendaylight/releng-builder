#!/bin/bash

# Format and mount rackspace data disk
mkfs -t ext3 /dev/xvde1
mkdir /w/workspace
mount /dev/xvde1 /w/workspace
chown jenkins:jenkins /w/workspace
