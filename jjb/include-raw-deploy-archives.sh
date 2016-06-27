#!/bin/bash
ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
LOGS_SERVER="https://logs.opendaylight.org"
echo "Build logs: <a href=\"$LOGS_SERVER/$SILO/$ARCHIVES_DIR\">$LOGS_SERVER/$SILO/$ARCHIVES_DIR</a>"

mkdir .archives
cd .archives/

cat > deploy-archives.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>logs</groupId>
  <artifactId>logs</artifactId>
  <version>1.0.0</version>
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
              <serverId>opendaylight-log-archives</serverId>
              <repositoryUrl>https://nexus.opendaylight.org/service/local/repositories/logs/content-compressed</repositoryUrl>
              <file>archives.zip</file>
              <repositoryPath>$SILO</repositoryPath>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF

mkdir -p $ARCHIVES_DIR
mv $WORKSPACE/archives/ $ARCHIVES_DIR
touch $ARCHIVES_DIR/_build-details.txt
echo "build-url: ${{BUILD_URL}}" >> $ARCHIVES_DIR/_build-details.txt
wget -O $ARCHIVES_DIR/_console-output.log ${{BUILD_URL}}consoleText
gzip $ARCHIVES_DIR/*.txt $ARCHIVES_DIR/*.log
# find and gzip all text files
find $ARCHIVES_DIR -name "*.txt" \
                -o -name "*.log" \
                -o -name "*.html" \
                | xargs gzip

zip -r archives.zip $JOB_NAME/
