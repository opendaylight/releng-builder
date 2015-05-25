#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# update os
yum clean all
yum update -q -y

# install mininet
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.1 2.2.1
cd ..
mininet/util/install.sh -nf

