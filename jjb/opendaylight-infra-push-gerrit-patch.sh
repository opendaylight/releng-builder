#!/bin/bash
CHANGE_ID=`ssh -p 29418 jenkins-$SILO@git.opendaylight.org gerrit query \
               limit:1 owner:self is:open project:{project} \
               message:'{gerrit-commit-message}' \
               topic:{gerrit-topic} | \
               grep 'Change-Id:' | \
               awk '{{ print $2 }}'`

if [ -z "$CHANGE_ID" ]; then
    git commit -sm "{gerrit-commit-message}"
else
    git commit -sm "{gerrit-commit-message}" -m "Change-Id: $CHANGE_ID"
fi

git status
git remote add gerrit ssh://jenkins-$SILO@git.opendaylight.org:29418/releng/builder.git
git review --yes -t {gerrit-topic}
