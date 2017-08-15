#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# If we detect a snapshot build then there is no need to run this script.
# YangIDE has indicated that the only want the latest snapshot released to
# the snapshot directory.
if echo "$P2ZIP_URL" | grep opendaylight.snapshot; then
    exit 0
fi
if [[ "$P2ZIP_URL" == "" ]]; then
    exit 0
fi

EPOCH_DATE=$(date +%s%3N)
MVN_METADATA=$(echo "$P2ZIP_URL" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')/maven-metadata.xml
P2_COMPOSITE_ARTIFACTS=compositeArtifacts.xml
P2_COMPOSITE_CONTENT=compositeContent.xml

wget "$MVN_METADATA" -O maven-metadata.xml

VERSIONS=$(xmlstarlet sel -t -m "/metadata/versioning/versions" -v "version" maven-metadata.xml)
NUM_VERSIONS=$(echo "$VERSIONS" | wc -w)


##
## Create compositeArtifacts.xml and compositeContent.xml files
##

cat > $P2_COMPOSITE_ARTIFACTS <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<?compositeArtifactRepository version='1.0.0'?>
<repository name='OpenDaylight $PROJECT'
    type='org.eclipse.equinox.internal.p2.artifact.repository.CompositeArtifactRepository' version='1.0.0'>
  <properties size='1'>
    <property name='p2.timestamp' value='$EPOCH_DATE'/>
  </properties>
  <children size='$NUM_VERSIONS'>
EOF

cat > $P2_COMPOSITE_CONTENT <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<?compositeMetadataRepository version='1.0.0'?>
<repository name='OpenDaylight $PROJECT'
    type='org.eclipse.equinox.internal.p2.metadata.repository.CompositeMetadataRepository' version='1.0.0'>
  <properties size='1'>
    <property name='p2.timestamp' value='$EPOCH_DATE'/>
  </properties>
  <children size='$NUM_VERSIONS'>
EOF

##
## Loop versions
##

for ver in $VERSIONS
do
    echo "    <child location='$ver'/>" >> $P2_COMPOSITE_ARTIFACTS
    echo "    <child location='$ver'/>" >> $P2_COMPOSITE_CONTENT
done

##
## Close files
##

cat >> $P2_COMPOSITE_ARTIFACTS <<EOF
  </children>
</repository>
EOF

cat >> $P2_COMPOSITE_CONTENT <<EOF
  </children>
</repository>
EOF

##
## Create poms for uploading
##

zip composite-repo.zip $P2_COMPOSITE_ARTIFACTS $P2_COMPOSITE_CONTENT

cat > deploy-composite-repo.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.opendaylight.$PROJECT</groupId>
  <artifactId>p2repo</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <packaging>pom</packaging>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-deploy-plugin</artifactId>
        <version>2.8.2</version>
        <configuration>
          <skip>true</skip>
        </configuration>
      </plugin>
      <plugin>
        <groupId>org.sonatype.plugins</groupId>
        <artifactId>maven-upload-plugin</artifactId>
        <version>0.0.1</version>
        <executions>
          <execution>
            <id>publish-site</id>
            <phase>deploy</phase>
            <goals>
              <goal>upload-file</goal>
            </goals>
            <configuration>
              <serverId>opendaylight-p2</serverId>
              <repositoryUrl>https://nexus.opendaylight.org/service/local/repositories/p2repos/content-compressed</repositoryUrl>
              <file>composite-repo.zip</file>
              <repositoryPath>org.opendaylight.$PROJECT/release</repositoryPath>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF
