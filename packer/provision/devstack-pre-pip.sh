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

set +e
echo "shague test pyyaml"
which python
whereis python
pip -V
pip show PyYAML
pip show requests

sudo find / -name "*PyYAML*"
sudo find / -name "*egg-info*"
sudo ls -al /usr/lib/py*
sudo ls -al /usr/lib/python2.7/site-packages
sudo ls -al /usr/lib/python3.4/site-packages

#pip uninstall -y PyYAML
#pip uninstall -y requests
#pip uninstall -y ipaddress
#pip uninstall -y pyOpenSSL

#sudo rm -rf /usr/lib/python2.7/dist-packages/yaml
#sudo rm -rf /usr/lib/python2.7/dist-packages/PyYAML-*
#sudo rm -rf /usr/lib/python3.4/dist-packages/yaml
#sudo rm -rf /usr/lib/python3.4/dist-packages/PyYAML-*

#sudo rm -rf /usr/lib/python2.7/site-packages/yaml
#sudo rm -rf /usr/lib/python2.7/site-packages/PyYAML-*
#sudo rm -rf /usr/lib64/python2.7/site-packages/PyYAML-*
#sudo rm -rf /usr/lib/python3.4/site-packages/yaml
#sudo rm -rf /usr/lib/python3.4/site-packages/PyYAML-*

sudo find / -name "*PyYAML*"
sudo find / -name "*egg-info*"
sudo ls -al /usr/lib/py*
sudo ls -al /usr/lib/python2.7/site-packages
sudo ls -al /usr/lib/python3.4/site-packages
set -e

#yum install PyYAML
#wget http://pyyaml.org/download/pyyaml/PyYAML-3.12.tar.gz
#tar -xzf PyYAML-3.12.tar.gz
#cd PyYAML-3.12
#python setup.py --without-libyaml install
#cd -

#wget https://bootstrap.pypa.io/get-pip.py
#python get-pip.py

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
    # sed -i s/PyYAML===3.12/PyYAML===3.10/ requirements/upper-constraints.txt
    pip install -c requirements/upper-constraints.txt -e "${proj}"
    pip install -c requirements/upper-constraints.txt -r "${proj}/test-requirements.txt"
done

echo '---> Installing openvswitch from relevant openstack branch'
yum install -y "centos-release-openstack-${branch_name}"

yum install -y --nogpgcheck openvswitch

cd "$OLDPWD"
rm -fr tmp

# vim: sw=4 ts=4 sts=4 et :
