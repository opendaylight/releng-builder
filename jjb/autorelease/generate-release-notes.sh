#!/bin/bash -x

# Generate the notes
pushd "$WORKSPACE/scripts/release_notes_management/"
java -jar "target/autonotes.jar"
popd

# Archive the notes
if [ -f  "$WORKSPACE/scripts/release_notes_management/projects/release-notes.rst" ]; then
    mkdir -p "$WORKSPACE/archives"
    cp -f "$WORKSPACE/scripts/release_notes_management/projects/release-notes.rst" "$WORKSPACE/archives"
fi

# Generate a docs patch for the notes
DOCS_DIR=$(mktemp -d)
git clone https://git.opendaylight.org/gerrit/docs.git "$DOCS_DIR"
cd "$DOCS_DIR" || exit 1
git checkout "$GERRIT_BRANCH"
cp -f "$WORKSPACE/scripts/release_notes_management/projects/release-notes.rst" \
    docs/getting-started-guide/release_notes.rst
git add docs/getting-started-guide/release_notes.rst

GERRIT_COMMIT_MESSAGE="Update release notes"
GERRIT_TOPIC="autogenerate-release-notes"
CHANGE_ID=$(ssh -p 29418 "jenkins-$SILO@git.opendaylight.org" gerrit query \
               limit:1 owner:self is:open project:docs \
               message:"$GERRIT_COMMIT_MESSAGE" \
               topic:"$GERRIT_TOPIC" | \
               grep 'Change-Id:' | \
               awk '{{ print $2 }}')

if [ -z "$CHANGE_ID" ]; then
   git commit -sm "$GERRIT_COMMIT_MESSAGE"
else
   git commit -sm "$GERRIT_COMMIT_MESSAGE" -m "Change-Id: $CHANGE_ID"
fi

git status
git remote add gerrit "ssh://jenkins-$SILO@git.opendaylight.org:29418/docs.git"

# Don't fail the build if this command fails because it's possible that there
# is no changes since last update.
git review --yes -t "$GERRIT_TOPIC" || true
