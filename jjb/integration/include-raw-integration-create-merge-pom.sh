# create a root pom that will contain a module for the ${PROJECT} and distribution
cat > ${WORKSPACE}/pom.xml <<EOF
<project>
  <groupId>org.opendaylight.integration</groupId>
  <artifactId>distribution-test</artifactId>
  <version>${BUNDLEVERSION}</version>
  <modelVersion>4.0.0</modelVersion>
  <packaging>pom</packaging>
  <modules>
    <module>${PROJECT}</module>
    <module>distribution</module>
  </modules>
</project>
EOF

