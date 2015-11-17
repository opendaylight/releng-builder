#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -qq \
    -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

# Install OpenVSwitch 2.3.1
add-apt-repository -y ppa:vshn/openvswitch
apt-get update -qq
apt-get install -y --force-yes -qq openvswitch-switch

# Install CPqD
apt-get install -y --force-yes -qq build-essential cmake flex
apt-get install -y --force-yes -qq libpcre++-dev libxerces-c-dev libpcap-dev libboost-all-dev

cd /tmp
wget -nc http://de.archive.ubuntu.com/ubuntu/pool/main/b/bison/bison_2.5.dfsg-2.1_amd64.deb \
         http://de.archive.ubuntu.com/ubuntu/pool/main/b/bison/libbison-dev_2.5.dfsg-2.1_amd64.deb

dpkg -i bison_2.5.dfsg-2.1_amd64.deb libbison-dev_2.5.dfsg-2.1_amd64.deb
rm bison_2.5.dfsg-2.1_amd64.deb libbison-dev_2.5.dfsg-2.1_amd64.deb

wget -nc http://www.nbee.org/download/nbeesrc-jan-10-2013.zip
unzip nbeesrc-jan-10-2013.zip
cd nbeesrc-jan-10-2013/src
cmake .
make
cp ../bin/libn*.so /usr/local/lib
ldconfig
cp -R ../include/* /usr/include/
cd ../..

git clone https://github.com/CPqD/ofsoftswitch13.git
cd ofsoftswitch13
./boot.sh
./configure
make
make install
cd ..

# Install mininet 2.2.1
git clone git://github.com/mininet/mininet
cd mininet
git checkout -b 2.2.1 2.2.1
cd ..
mininet/util/install.sh -nf

# cbench installation for running openflow performance tests

OF_DIR=$HOME/openflow  # Directory that contains OpenFlow code
OFLOPS_DIR=$HOME/oflops  # Directory that contains oflops repo

apt-get install -y --force-yes -qq libsnmp-dev libpcap-dev libconfig-dev

git clone git://gitosis.stanford.edu/openflow.git $OF_DIR
git clone https://github.com/andi-bigswitch/oflops.git $OFLOPS_DIR

cd $OFLOPS_DIR
./boot.sh
./configure --with-openflow-src-dir=$OF_DIR
make
make install
