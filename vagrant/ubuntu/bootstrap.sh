#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
apt-get upgrade -y --force-yes -qq
