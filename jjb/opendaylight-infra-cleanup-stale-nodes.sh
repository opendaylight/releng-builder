#!/bin/bash

# Todo: As a safe check we could obtain the list of active jobs from Jenkins and
# compute the checksum from $JOB_NAME to check if any active nodes exist and
# skip deleting those nodes. This step may not be required since there is already
# 24H timeout in place for all jobs therefore all jobs are expected to complete
# within the timeout.

lftools openstack --os-cloud rackspace \
    server list --days=1
lftools openstack --os-cloud rackspace \
    server cleanup --days=1
