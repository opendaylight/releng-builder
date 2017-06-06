#!/bin/bash
# Build script for opflex

set -e
set -x

sudo cat > /etc/yum.repos.d/fdio-stable-1704.repo <<EOF
[fdio-stable-1704]

name=fd.io stable/1704 branch latest merge
baseurl=https://nexus.fd.io/content/repositories/fd.io.stable.1704.centos7/
enabled=1
gpgcheck=0
EOF

sudo yum install vpp
