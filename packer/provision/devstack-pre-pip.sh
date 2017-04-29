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
branch=${os_branch}

wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py

mkdir tmp
cd tmp

git clone https://github.com/openstack-dev/devstack.git
(cd devstack && git checkout ${branch})
sed -e 's/#.*//' devstack/files/rpms/general | xargs yum install -y

base_url=https://github.com/openstack/
for proj in $projs
do
    git clone ${base_url}${proj}
    (cd ${proj} && git checkout ${branch})
    pip install -c requirements/upper-constraints.txt -e ${proj}
    pip install -c requirements/upper-constraints.txt -r ${proj}/test-requirements.txt
done

# the ocata release has ovs 2.6.1
echo '---> Installing openvswitch from openstack Ocata repo (2.6.1)'
yum install -y http://rdoproject.org/repos/openstack-ocata/rdo-release-ocata.rpm

yum install -y --nogpgcheck openvswitch

cd $OLDPWD
rm -fr tmp

# vim: sw=4 ts=4 sts=4 et :
