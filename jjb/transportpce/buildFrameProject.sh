#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script builds a Maven project and deploys it into a staging repo which
# can be used to deploy elsewhere later eg. Nexus staging / snapshot repos.

# DO NOT enable -u because $MAVEN_PARAMS and $MAVEN_OPTIONS could be unbound.
# Ensure we fail the job if any steps fail.

if [ ! -z "$TOX_ENVS" ]; then
  yang="\
  mdsal/model/iana/iana-afn-safi/src/main/yang/iana-afn-safi@2013-07-04.yang \
  mdsal/model/ietf/ietf-inet-types-2013-07-15/src/main/yang/ietf-inet-types@2013-07-15.yang \
  mdsal/model/ietf/ietf-yang-types-20130715/src/main/yang/ietf-yang-types@2013-07-15.yang \
  netconf/netconf/models/ietf-netconf/src/main/yang/ietf-netconf@2011-06-01.yang \
  netconf/netconf/models/ietf-netconf-notifications/src/main/yang/ietf-netconf-notifications@2012-02-06.yang \
  netconf/netconf/models/ietf-netconf-notifications/src/main/yang/notifications@2008-07-14.yang"
  
  cd "$WORKSPACE"
  rm -rf netconf mdsal && git submodule update --init
  echo "--> finish submodule"
  cd "$WORKSPACE/$TOX_DIR"
  (cd netconf && patch -p1 < ../netconf.patch && patch -p1 < ../get_connection_port_trail.patch)
  
  
  set -e -o pipefail
  set +u
  export MAVEN_OPTS
  
  #Build netconf project
  cd "$WORKSPACE/$TOX_DIR"
  cd netconf/netconf/tools/netconf-testtool
  # Disable SC2086 because we want to allow word splitting for $MAVEN_* parameters.
  # shellcheck disable=SC2086
  $MVN clean install dependency:tree com.sonatype.clm:clm-maven-plugin:index \
      --global-settings "$GLOBAL_SETTINGS_FILE" \
      --settings "$SETTINGS_FILE" \
      -DaltDeploymentRepository=staging::default::file:"$WORKSPACE"/m2repo \
      $MAVEN_OPTIONS $MAVEN_PARAMS\
      -DskipTests\
      -Dmaven.javadoc.skip=true
  
  #Build honeycomb project
  cd "$WORKSPACE/$TOX_DIR"
  cd honeynode
  $MVN clean install dependency:tree com.sonatype.clm:clm-maven-plugin:index \
      --global-settings "$GLOBAL_SETTINGS_FILE" \
      --settings fd_io_honeycomb_settings.xml \
      -DaltDeploymentRepository=staging::default::file:"$WORKSPACE"/m2repo \
      $MAVEN_OPTIONS $MAVEN_PARAMS\
      -DskipTests\
      -Dmaven.javadoc.skip=true
  chmod +x ./honeynode-distribution/target/honeynode-distribution-1.18.01-hc/honeynode-distribution-1.18.01/honeycomb-tpce
  
  #Copy schemas
  cd "$WORKSPACE/$TOX_DIR"
  rm -rf schemas && mkdir -p schemas
  cp ordmodels_1.2.1/org-openroadm-* schemas
  cp ${yang} schemas
fi

exit $?
