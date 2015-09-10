#!/bin/bash

# vim: sw=4 ts=4 sts=4 et :

rh_changes() {
    # make sure we're fully updated
    echo "---> Updating OS"
    yum clean all
    yum update -y -q

    # install docker and enable it
    echo "---> Installing docker"
    yum install -y docker supervisor bridge-utils
    systemctl enable docker

    # configure docker networking so that it does not conflict with LF
    # internal networks
    cat <<EOL > /etc/sysconfig/docker-network
# /etc/sysconfig/docker-network
DOCKER_NETWORK_OPTIONS='--bip=10.250.0.254/24'
EOL
    # configure docker daemon to listen on port 5555 enabling remote 
    # managment
    sed -i -e "s#='--selinux-enabled'#='--selinux-enabled -H unix:///var/run/docker.sock -H tcp://0.0.0.0:5555'#g" /etc/sysconfig/docker

    # docker group doesn't get created by default for some reason
    groupadd docker
}

ubuntu_changes() {
    # make sure we're fully updated
    echo "---> Updating OS"
    apt-get update
    apt-get upgrade -y -qq
}

OS=`/usr/bin/facter operatingsystem`
case "$OS" in
    CentOS|Fedora|RedHat)
        rh_changes
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
