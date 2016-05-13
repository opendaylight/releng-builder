#!/bin/bash

#######################
# Create Jenkins User #
#######################

# Find $DISTRO
for i in $(ls /home); do
    case "${i}" in
        centos|fedora|ubuntu)
            DISTRO=$i
        ;;
        *)
            DISTRO=unknown
        ;;
    esac
done

useradd -m jenkins
mkdir /home/jenkins/.ssh
mkdir /w
cp -r /home/${DISTRO}/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh /w
