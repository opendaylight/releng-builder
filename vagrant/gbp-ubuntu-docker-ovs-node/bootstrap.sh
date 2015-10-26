#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

echo "---> Updating operating system"
apt-get update -qq
apt-get upgrade -y --force-yes -qq

# we need garethr-docker in our puppet manifest to install docker
# cleanly
puppet module install garethr-docker --version 4.1.1

# do the package install via puppet so that we know it actually installs
# properly and it also makes it quieter but with better error reporting
echo "---> Installing Group Based Policy requirements"
puppet apply /vagrant/gbp_packages.pp

# configure docker networking so that it does not conflict with LF internal networks
# configure docker daemon to listen on port 5555 enabling remote managment
# This has to happen before docker gets installed or things go sideways
# badly
cat <<EOL > /etc/default/docker
# /etc/default/docker
DOCKER_OPTS='-H unix:///var/run/docker.sock -H tcp://0.0.0.0:5555 --bip=10.250.0.254/24'
EOL

# docker
echo "---> Installing docker"
puppet apply /vagrant/docker_setup.pp

echo "---> stopping docker"
puppet apply -e "service { 'docker': ensure => stopped }"

echo "---> cleaning docker configs that break after snapshotting"
rm -f /var/lib/docker/repositories-aufs /etc/docker/key.json

# OVS
echo "---> Installing ovs"
puppet module install puppetlabs-vcsrepo
puppet apply /vagrant/ovs_setup.pp

pushd /root/ovs
DEB_BUILD_OPTIONS='parallel=8 nocheck' fakeroot debian/rules binary | \
 grep 'dpkg-deb: building package'
popd

# Note this does not actually install OVS. Everytime we've tried to do
# that the snapshot system hangs on spin-up for some reason. As such the
# final installation will have to be left as a spin-up task

# The following is what should be used in the spin-up task
# dpkg --install /root/openvswitch-datapath-dkms* && dpkg --install /root/openvswitch-{common,switch}*
