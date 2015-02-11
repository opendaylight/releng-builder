#!/bin/bash

set -e

echo "---> Cleaning up"
docker logs $CID > $WORKSPACE/docker-ovs-${OVS_VERSION}.log
docker stop $CID
docker rm $CID
rm env.properties

docker images
