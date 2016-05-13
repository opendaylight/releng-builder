jenkins-jobs update --recursive --delete-old --workers 0 jjb/

# Submit patches for any jobs that can be auto updated
function submitJJB {
    git commit -asm "Update automated project templates"
    git push origin HEAD:refs/for/master
}

gitdir=$(git rev-parse --git-dir); scp -p -P 29418 jenkins-releng@git.opendaylight.org:hooks/commit-msg ${gitdir}/hooks/
python scripts/jjb-autoupdate-project.py
git diff --exit-code || submitJJB
