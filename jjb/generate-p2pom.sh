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

if [[ "$P2ZIP_URL" == "" ]]; then
    P2ZIP_URL=opendaylight.snapshot/$(find . -name "*.zip" -type f -exec ls "{}" + | head -1)
    FILE_NAME=$(echo "$P2ZIP_URL" | awk -F'/' '{ print $NF }')
    RELEASE_PATH="snapshot"
else
    FILE_NAME=$(echo "$P2ZIP_URL" | awk -F'/' '{ print $NF }')
    VERSION=$(echo "$P2ZIP_URL" | awk -F'/' '{ print $(NF-1) }')
    RELEASE_PATH="release/$VERSION"
    wget --quiet "$P2ZIP_URL" -O "$FILE_NAME"
fi

# If we detect a snapshot build then release to a snapshot repo
# YangIDE has indicated that the only want the latest snapshot released to
# the snapshot directory.
if echo "$P2ZIP_URL" | grep opendaylight.snapshot; then
    RELEASE_PATH="snapshot"
fi

cat > "${WORKSPACE}/pom.xml" <<EOF
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
              <file>$FILE_NAME</file>
              <repositoryPath>org.opendaylight.$PROJECT/$RELEASE_PATH</repositoryPath>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF
