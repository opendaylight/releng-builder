#!/bin/bash

set -e

echo "---> Setting up controller IP"
CONTROLLER_IP=`facter ipaddress`
echo "CONTROLLER_IP=${CONTROLLER_IP}" > env.properties
