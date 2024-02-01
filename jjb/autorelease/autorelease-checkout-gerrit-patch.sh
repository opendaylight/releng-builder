#!/bin/bash -l
set -eu -o pipefail

# If the project is autorelease then we do not need to cd
if [ "$GERRIT_PROJECT" != "releng/autorelease" ]; then
    cd "$WORKSPACE/$GERRIT_PROJECT"
fi

echo "Checking out ${GERRIT_PROJECT} patch ${GERRIT_REFSPEC}..."
git fetch origin "${GERRIT_REFSPEC}" && git checkout FETCH_HEAD

# If the project is autorelease then we need to init and update submodules
if [ "$GERRIT_PROJECT" == "releng/autorelease" ]; then
    git submodule update --init
    # The previous checkout might have failed to remove directory of a submodule being removed.
    # See https://stackoverflow.com/a/10761699
    git clean -dff
fi
