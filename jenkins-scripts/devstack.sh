#!/bin/bash

# add in a test copr repo
wget http://copr.fedoraproject.org/coprs/tykeal/odl-updates/repo/epel-7/tykeal-odl-updates-epel-7.repo -O /etc/yum.repos.d/tykeal-odl-updates-epel-7.repo

yum clean all

# Install xpath
yum install -y perl-XML-XPath

yum update -y python-six 

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
EOF

# vim: sw=2 ts=2 sts=2 et :
