#!/bin/bash

set +e  # Do not affect the build result if some part of archiving fails.

# Print out git status at the end of the build before we archive if $WORKSPACE
# is a git repo.
if [ -d "$WORKSPACE/.git" ]; then
    echo ""
    echo "----------> Git Status Report"
    git status
fi

echo ""
echo "----------> Archiving build to logs server"
# Configure wget to not print download status when we download logs or when
# Jenkins is installing Maven (To be clear this is the Jenkins Maven plugin
# using a shell script itself that we are unable to modify directly to affect
# wget).
echo "verbose=off" > ~/.wgetrc

ARCHIVES_DIR="$JENKINS_HOSTNAME/$JOB_NAME/$BUILD_NUMBER"
[ "$LOGS_SERVER" ] || LOGS_SERVER="https://logs.opendaylight.org"
[ "$LOGS_REPO_URL" ] || LOGS_REPO_URL="https://nexus.opendaylight.org/service/local/repositories/logs"

echo "Build logs: <a href=\"$LOGS_SERVER/$SILO/$ARCHIVES_DIR\">$LOGS_SERVER/$SILO/$ARCHIVES_DIR</a>"

mkdir .archives
cd .archives/ || exit 1

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
              <repositoryUrl>$LOGS_REPO_URL/content-compressed</repositoryUrl>
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

mkdir -p "$ARCHIVES_DIR"
mkdir -p "$WORKSPACE/archives"
if [ ! -z "$ARCHIVE_ARTIFACTS" ]; then
    pushd "$WORKSPACE"
    shopt -s globstar  # Enable globstar to copy archives
    for f in $ARCHIVE_ARTIFACTS; do
        [[ -e $f ]] || continue  # handle the case of no files to archive
        echo "Archiving $f" >> "$WORKSPACE/.archives/$ARCHIVES_DIR/_archives.log"
        dir=$(dirname "$f")
        mkdir -p "$WORKSPACE/archives/$dir"
        mv "$f" "$WORKSPACE/archives/$f"
    done
    shopt -u globstar  # Disable globstar once archives are copied
    popd
fi


# Ignore logging if archives doesn't exist
mv "$WORKSPACE/archives/" "$ARCHIVES_DIR" > /dev/null 2>&1
touch "$ARCHIVES_DIR/_build-details.txt"
echo "build-url: ${BUILD_URL}" >> "$ARCHIVES_DIR/_build-details.txt"
env | grep -v PASSWORD | sort > "$ARCHIVES_DIR/_build-enviroment-variables.txt"

# capture system info
touch "$ARCHIVES_DIR/_sys-info.txt"
{
    echo -e "uname -a:\n $(uname -a) \n"
    echo -e "df -h:\n $(df -h) \n"
    echo -e "free -m:\n $(free -m) \n"
    echo -e "nproc:\n $(nproc) \n"
    echo -e "lscpu:\n $(lscpu) \n"
    echo -e "ip addr:\n  $(/sbin/ip addr) \n"
} 2>&1 | tee -a "$ARCHIVES_DIR/_sys-info.txt"

# Magic string used to trim console logs at the appropriate level during wget
echo "-----END_OF_BUILD-----"
wget -O "$ARCHIVES_DIR/console.log" "${BUILD_URL}consoleText"
wget -O "$ARCHIVES_DIR/console-timestamp.log" "$BUILD_URL/timestamps?time=HH:mm:ss&appendLog"
sed -i '/^-----END_OF_BUILD-----$/,$d' "$ARCHIVES_DIR/console.log"
sed -i '/^.*-----END_OF_BUILD-----$/,$d' "$ARCHIVES_DIR/console-timestamp.log"

gzip "$ARCHIVES_DIR"/*.txt "$ARCHIVES_DIR"/*.log
# find and gzip any 'text' files
find "$ARCHIVES_DIR" -type f -print0 \
                | xargs -0r file \
                | egrep -e ':.*text.*' \
                | cut -d: -f1 \
                | xargs -d'\n' -r gzip
# Compress Java heap dumps using xz
find "$ARCHIVES_DIR" -type f -name \*.hprof -print0 | xargs -0 xz

zip -r archives.zip "$JENKINS_HOSTNAME/" >> "$ARCHIVES_DIR/_archives.log"
du -sh archives.zip
