#!/bin/bash

echo '---> Installing non-baseline requirements'
yum install -y deltarpm python{,-{crypto,devel,lxml,setuptools}} \
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

cd $OLDPWD
rm -fr tmp

# vim: sw=4 ts=4 sts=4 et :
