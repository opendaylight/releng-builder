#!/bin/sh

CONTAINER_PULL_REGISTRY=nexus3.opendaylight.org:10003
CONTAINER_PUSH_REGISTRY=nexus3.opendaylight.org:10002
DOCKER_REGISTRY=nexus3.opendaylight.org
DOCKERHUB_REGISTRY=docker.io
GERRIT_URL=https://git.opendaylight.org/gerrit
GIT_BASE=git://devvexx.opendaylight.org/mirror/$PROJECT
GIT_URL=git://devvexx.opendaylight.org/mirror
JENKINS_HOSTNAME=vex-yul-odl-jenkins-2
LOGS_SERVER=
NEXUS_URL=https://nexus.opendaylight.org
ODLNEXUSPROXY=https://nexus.opendaylight.org
REGISTRY_PORTS=10001 10002 10003 10004
SIGUL_BRIDGE_IP=199.204.45.55
SIGUL_KEY=odl-sandbox
SILO=sandbox
SONAR_URL=https://sonar.opendaylight.org
S3_BUCKET=odl-logs-s3-cloudfront-index
CDN_URL=s3-logs.opendaylight.org
