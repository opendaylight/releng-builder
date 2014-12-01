source /opt/virtualenv/jenkins-job-builder/bin/activate
jenkins-jobs update jjb/

# Submit patches for any jobs that can be auto updated
gitdir=$(git rev-parse --git-dir); scp -p -P 29418 jenkins-releng@git.opendaylight.org:hooks/commit-msg ${gitdir}/hooks/
python scripts/jjb-autoupdate-project.py
git commit -asm "Update automated project templates"
git push origin HEAD:refs/for/master
