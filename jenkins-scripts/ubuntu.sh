#!/bin/bash
 
# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF
 
# setup for OVS & Docker
apt-get -y remove grub-pc
apt-get -y install grub-pc
grub-install /dev/sda # precaution
update-grub
apt-get install -f -y > /dev/null
apt-get clean -y > /dev/null
apt-get autoclean -y > /dev/null
apt-get update
apt-get -y upgrade
apt-get install -y software-properties-common > /dev/null
apt-get install -y python-software-properties > /dev/null
apt-get install -y git-core git > /dev/null
apt-get install -y docker.io > /dev/null
apt-get install -y vim > /dev/null
ln -sf /usr/bin/docker.io /usr/local/bin/docker
sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io
update-rc.d docker.io defaults
sudo docker pull alagalah/odlpoc_ovs230
apt-get install -y curl > /dev/null
apt-get install -y python-pip
pip install ipaddr
echo "export PATH=$PATH:/vagrant" >> /home/vagrant/.profile
echo "export ODL=#{odl}" >> /home/vagrant/.profile    
export ODL=#{odl}
curl https://raw.githubusercontent.com/pritesh/ovs/nsh-v8/third-party/start-ovs-deb.sh | bash
