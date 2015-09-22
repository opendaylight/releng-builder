#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
apt-get upgrade -y --force-yes -qq

echo "---> Installing Group Based Policy requirements"
apt-get install -y software-properties-common -qq
apt-get install -y python-software-properties -qq
apt-get install -y python-pip -qq
apt-get install -y git-core git -qq
apt-get install -y curl -qq
apt-get install -y bridge-utils -qq

# docker
curl -sSL https://get.docker.com/ | sh

# configure docker networking so that it does not conflict with LF internal networks
# configure docker daemon to listen on port 5555 enabling remote managment
cat <<EOL > /etc/default/docker
# /etc/default/docker
DOCKER_OPTS='-H unix:///var/run/docker.sock -H tcp://0.0.0.0:5555 --bip=10.250.0.254/24'
EOL
ip link set dev docker0 down
brctl delbr docker0
restart docker

docker pull alagalah/odlpoc_ovs230
# OVS
curl https://raw.githubusercontent.com/pritesh/ovs/nsh-v8/third-party/start-ovs-deb.sh | bash
