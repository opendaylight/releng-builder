cd "${GERRIT_PROJECT}"
export EMAIL="sandbox@jenkins.opendaylight.org"
# TODO: Is there a more appropriate e-mail?
export GIT_COMMITTER_NAME="Rebase Macro"
git rebase "${BRANCH}"
cd "${WORKSPACE}"
