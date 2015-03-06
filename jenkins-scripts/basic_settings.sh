#!/bin/bash

#Increase limits
cat <<EOF > /etc/security/limits.d/jenkins
jenkins               soft     nofile         16000
jenkins               hard    nofile         16000
EOF

cat <<EOSSH >> /etc/ssh/ssh_config

# we don't want to do SSH host key checking on Rackspace spin-up systems
Host 10.30.11.*
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOSSH

cat <<EOKNOWN >  /etc/ssh/ssh_known_hosts
[140.211.169.26]:29418,[git.opendaylight.org]:29418 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyRXyHEw/P1iZr/fFFzbodT5orVV/ftnNRW59Zh9rnSY5Rmbc9aygsZHdtiWBERVVv8atrJSdZool75AglPDDYtPICUGWLR91YBSDcZwReh5S9es1dlQ6fyWTnv9QggSZ98KTQEuE3t/b5SfH0T6tXWmrNydv4J2/mejKRRLU2+oumbeVN1yB+8Uau/3w9/K5F5LgsDDzLkW35djLhPV8r0OfmxV/cAnLl7AaZlaqcJMA+2rGKqM3m3Yu+pQw4pxOfCSpejlAwL6c8tA9naOvBkuJk+hYpg5tDEq2QFGRX5y1F9xQpwpdzZROc5hdGYntM79VMMXTj+95dwVv/8yTsw==
EOKNOWN

# vim: sw=2 ts=2 sts=2 et :
