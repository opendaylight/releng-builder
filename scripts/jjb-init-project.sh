#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: ./jjb-init-project <project> \"[maven-goals]\" \"[maven-opts]\""
    echo ""
    echo "Example: ./jjb-init-project aaa \"clean install\" \"-Xmx1024m\""
    exit 1
fi

PROJECT=$1
MAVEN_GOALS=$2   # Defaults to "clean install" if not passsed
MAVEN_OPTS=$3    # Defaults to blank if not passed

if [[ -z "$MAVEN_GOALS" ]]; then
    MAVEN_GOALS="clean install"
fi

# Create project directory if it doesn't exist already
if [[ ! -e "jjb/$PROJECT" ]]; then
    mkdir jjb/$PROJECT
fi

# Create initial project YAML file
sed -e "/^[^#]/ s/PROJECT/$PROJECT/" \
    -e "/^[^#]/ s/MAVEN_GOALS/$MAVEN_GOALS/" \
    -e "/^[^#]/ s/MAVEN_OPTS/$MAVEN_OPTS/" \
    jjb/job.yaml.template > jjb/$PROJECT/$PROJECT.yaml
