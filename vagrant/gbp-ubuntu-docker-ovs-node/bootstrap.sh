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
# docker
curl -sSL https://get.docker.com/ | sh
usermod -aG docker jenkins
docker pull alagalah/odlpoc_ovs230
# OVS
curl https://raw.githubusercontent.com/pritesh/ovs/nsh-v8/third-party/start-ovs-deb.sh | bash
