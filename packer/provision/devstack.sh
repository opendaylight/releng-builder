#!/bin/bash

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# Install xpath
yum install -y perl-XML-XPath python-pip python-six

# install crudini command line tool for editing config files
yum install -y crudini

echo '---> Installing non-baseline requirements'
yum install -y deltarpm python{,-{crypto,devel,lxml,setuptools}} \
    @development {lib{xml2,xslt,ffi},openssl}-devel

echo '---> Updating net link setup'
if [ ! -f /etc/udev/rules.d/80-net-setup-link.rules ]; then
    ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"

# vim: sw=4 ts=4 sts=4 et :
