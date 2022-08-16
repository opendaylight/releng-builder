#!/bin/sh

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# make sure jenkins is part of the docker only if jenkins has already been
# created

if grep -q jenkins /etc/passwd
then
  /usr/sbin/usermod -a -G docker jenkins
fi

# vim: sw=2 ts=2 sts=2 et :
