#!/bin/bash

git log --show-signature -1 | egrep -q 'gpg: Signature made.*key ID'
if [ $? -eq 0 ]; then
   echo "git commit is gpg signed"
else
   echo "WARNING: gpg signature missing for the commit"
fi

# Don't fail the job for unsigned commits
exit 0
