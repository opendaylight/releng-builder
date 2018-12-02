#/bin/bash

# install the dependencies for RHEL
sudo yum -y install docker pip

# install docker-py
sudo pip install molecule docker-py -y

# Change directory to ODL role
cd /etc/ansible/roles/opendaylight

# Initialize the scenario
molecule init scenario --role-name opendaylight --driver-name docker --verfier-name testinfra

# Create the containers
molecule create

# Configure the containers
molecule converge
