basic-mininet-fedora-node can be used to take an already converted
Rackspace native base image to a basic system with mininet and other
test tools for use in the OpenDaylight build and testing environment

Please see the rackspace-convert-base vagrant setup for creation of the
needed base image.

This vagrant expects (by default) a personal Rackspace image named

'Fedora 21 - Vagrant ready'

To spin up and utilize.

$ RSIMAGE='${baseimagename}' vagrant up --provider=rackspace

Will execute this vagrant against a differently named base image

$ RSRESEAL=true vagrant up --provider=rackspace

NOTE: resealing will cause the vagrant to run the resealing operation.
This operation will intentionally destroy current SSH pubkeys installed
on the system as well as reset log files and network configurations. You
have been warned.
