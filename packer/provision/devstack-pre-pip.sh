#!/bin/bash

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# add in a test copr repo
wget http://copr.fedoraproject.org/coprs/tykeal/odl-updates/repo/epel-7/tykeal-odl-updates-epel-7.repo -O /etc/yum.repos.d/tykeal-odl-updates-epel-7.repo
# Install xpath
yum install -y perl-XML-XPath python-pip python-six

# install crudini command line tool for editing config files
yum install -y crudini

echo '---> Installing non-baseline requirements'
yum install -y deltarpm nc python{,-{crypto,devel,lxml,setuptools}} \
    @development {lib{xml2,xslt,ffi},openssl}-devel git wget

echo '---> Updating net link setup'
if [ ! -f /etc/udev/rules.d/80-net-setup-link.rules ]; then
    ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi

echo '---> Pre-installing yum and pip packages'
projs="requirements keystone glance cinder neutron nova horizon"
# shellcheck disable=SC2154
branch=${os_branch}
# strip the "stable" off of the branch
branch_name=$(cut -d'/' -f2 <<< "${branch}")

# Do not upgrade pip to v10. v10 does not allow uninstalling
# distutils installed packages. This fails the openstack pip installs
# below when it attempts to uninstall packages.
# devstack patch that is trying to get pip 10 working:
# https://review.openstack.org/#/c/561597/
# wget https://bootstrap.pypa.io/get-pip.py
# python get-pip.py

mkdir tmp
cd tmp

git clone https://github.com/openstack-dev/devstack.git
(cd devstack && git checkout "${branch}")
sed -e 's/#.*//' devstack/files/rpms/general | xargs yum install -y

base_url=https://github.com/openstack/
for proj in $projs
do
    git clone "${base_url}${proj}"
    (cd "${proj}" && git checkout "${branch}")
    pip install -c requirements/upper-constraints.txt -e "${proj}"
    pip install -c requirements/upper-constraints.txt -r "${proj}/test-requirements.txt"
done

echo '---> Installing openvswitch from relevant openstack branch'
yum install -y "centos-release-openstack-${branch_name}"

# install 2.8.2 for queens.
# 2.9.0 is the current version in openstack-queens, but it is buggy.
# Remove this when https://review.rdoproject.org/r/#/c/13839/ merges and 2.9.2 is in the repo.
yum repolist
yum --showduplicates list openvswitch

if [ "${install_ovs}" == "yes" ]; then
    if [ "${branch}" == "stable/queens" ]; then
        yum install -y --nogpgcheck openvswitch-2.8.2-1.el7
    else
        yum install -y --nogpgcheck openvswitch
    fi
fi
cd "$OLDPWD"
rm -fr tmp

# vim: sw=4 ts=4 sts=4 et :
