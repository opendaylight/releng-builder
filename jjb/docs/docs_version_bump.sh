#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2019 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

update_file_usage () {
    echo "Usage: $0 <RELEASE_NAME> <PUBLISH>"
    echo ""
    echo "    RELEASE_NAME:  The RELEASE_NAME eg: Titanium, Vanadium."
    echo "    PUBLISH:  Set to true to PUBLISH"
    echo ""
}
while getopts :h: opts; do
  case "$opts" in
    h)
        update_file_usage
        exit 0
        ;;
    [?])
        update_file_usage
        exit 1
        ;;
  esac
done
set +u  # Allow unbound variables for virtualenv
virtualenv --quiet "/tmp/v/git-review"
# shellcheck source=/tmp/v/git-review/bin/activate disable=SC1091
. "/tmp/v/git-review/bin/activate"
pip install --quiet --upgrade "pip==9.0.3" setuptools
pip install --quiet --upgrade git-review
git config --global --add gitreview.username "jenkins-$SILO"
cd "$WORKSPACE"/docs || exit
RELEASE_NAME=${RELEASE_NAME:-}
Next_release="$(tr '[:lower:]' '[:upper:]' <<< "${RELEASE_NAME:0:1}")${RELEASE_NAME:1}" # Captilize Version Name
release_name=$STREAM
Release_version="$(tr '[:lower:]' '[:upper:]' <<< "${release_name:0:1}")${release_name:1}" # Captilize Version Name
PUBLISH=${PUBLISH:-}
stable_release_str=stable-$release_name
echo "Start Version Updating in docs project"
echo "RELEASE_NAME : $Next_release"
if [ "$GERRIT_BRANCH" == "master" ]
then
    # ####################################
    # # Changes in the master branch #
    # ####################################
    git checkout master
    odl_release_str=odl-$release_name
    next_odl_release_str=odl-$RELEASE_NAME
    #change the odl-<release> linking to stable-<release> to odl-<next_release> linking to latest
    sed -i "s/$odl_release_str/$next_odl_release_str/g;" docs/conf.py
    sed -i "s/$stable_release_str/latest/g;" docs/conf.py

    # Get the value of line with odl-<release> linking to stable-<release>
    # for appending it to the line next to odl-<next_release> linking to latest
    line_number_nr=$(sed -n "/$next_odl_release_str/=" docs/conf.py)
    pattern=$line_number_nr"p"
    odl_latest="sed -n $pattern docs/conf.py"
    odl_latest_line_value=$($odl_latest)
    append_odl_latest=$(echo "$odl_latest_line_value" | sed "s/latest/$stable_release_str/g; s/$RELEASE_NAME/$release_name/g" )
    echo "Making changes in Master Branch"
    # Update docs/conf.py
    # sed -i "$line_number_nr'i'\
    # $append_odl_latest" docs/conf.py
    sed -i "$line_number_nr a $append_odl_latest" docs/conf.py
    # Updating version in docs/conf.yaml
    sed -i "s/$Release_version/$Next_release/g" docs/conf.yaml
    # Updating version in docs/javadoc.rst
    sed -i "s/$release_name/$RELEASE_NAME/g" docs/javadoc.rst
    if [ "$PUBLISH" == "true" ]
    then
            git add docs/conf.py docs/conf.yaml docs/javadoc.rst
            echo "Update configuratiom files in master branch"
            git commit -s -m "Update configuratiom files in master branch

            In docs/conf.py , add odl-$RELEASE_NAME pointing to latest
            and change odl-$release_name to point to stable-$release_name.
            In docs/conf.yaml
            Change version from $Release_version to $Next_release.
            In docs/javadoc.rst
            Change links from $release_name to $RELEASE_NAME"
            git review
    fi
else
    ####################################
    # Changes in the new stable branch #
    ####################################
    echo "Making changes in $GERRIT_BRANCH"

    # #Updating links in docs/conf.py
    sed -i "s/latest/$stable_release_str/g" docs/conf.py
    if [ "$PUBLISH" == "true" ]
    then
            git add docs/conf.py
            echo "Update docs/conf.py links from latest to $stable_release_str"
            git commit -s -m "Update docs/conf.py links from latest to $stable_release_str

            Should be $stable_release_str on ${GERRIT_BRANCH}."
            git review
    fi
fi
