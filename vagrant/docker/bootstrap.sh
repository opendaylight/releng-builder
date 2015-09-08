#!/bin/bash

# vim: sw=4 ts=4 sts=4 et :

fedora_changes() {
    # make sure we're fully updated
    echo "---> Updating OS"
    dnf clean all
    dnf update -y -q

    # install docker and enable it
    echo "---> Installing docker"
    dnf install -y docker supervisor bridge-utils
    systemctl enable docker

    # configure docker networking so that it does not conflict with LF
    # internal networks
    cat <<EOL > /etc/sysconfig/docker-network
# /etc/sysconfig/docker-network
DOCKER_NETWORK_OPTIONS='--bip=10.250.0.254/24'
EOL

    # docker group doesn't get created by default for some reason
    groupadd docker
}

el_changes() {
    # make sure we're fully updated
    echo "---> Updating OS"
    yum clean all
    yum update -q -y
}

ubuntu_changes() {
    # make sure we're fully updated
    echo "---> Updating OS"
    apt-get update
    apt-get upgrade -y -qq
}

OS=`/usr/bin/facter operatingsystem`
case "$OS" in
    Fedora)
        fedora_changes
    ;;
    Centos|RedHat)
        el_changes
    ;;
    Ubuntu)
        ubuntu_changes
    ;;
    *)
        echo "${OS} has no configuration changes"
    ;;
esac

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"
