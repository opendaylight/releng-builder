#!/bin/bash

# install the dependencies for RHEL
sudo apt-get -y install docker

# install docker-py
sudo pip install molecule docker-py

# Change directory to ODL role
cd /etc/ansible/roles/opendaylight || return

# Initialize the scenario
molecule init scenario --role-name opendaylight --driver-name docker --verifier-name testinfra

# Create the containers
molecule create

# Configure the containers
molecule converge

