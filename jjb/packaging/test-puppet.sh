#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Adapted from puppet-opendaylight/Vagrantfile
# https://git.opendaylight.org/gerrit/gitweb?p=integration/packaging/puppet-opendaylight.git;a=blob;f=Vagrantfile

# Install system-wide dependencies
# TODO: Are all of these still needed?
# net-tools: Needed for netstat, used by acceptance test that checks bind IPs
sudo yum install -y ruby-devel gcc-c++ zlib-devel patch redhat-rpm-config \
                    make rubygems net-tools

# Install RVM to help build recent version of Ruby
# The ruby_dep gem requires >=2.2.5, 2.0.0 is the latest pre-packaged for CentOS
gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -L get.rvm.io | bash -s stable
# Expected by RVM, seems required to make RVM functions (`rvm use`) available
# Silence absurdly verbose rvm output by temporally not echoing commands
set +x
# shellcheck disable=SC1090
source "$HOME/.rvm/scripts/rvm"
rvm install 2.4.0
set -x
ruby --version
# This has to be done as a login shell to get rvm fns
# https://rvm.io/support/faq#what-shell-login-means-bash-l
# http://superuser.com/questions/306530/run-remote-ssh-command-with-full-login-shell
bash -lc "rvm use 2.4.0 --default"
ruby --version

# Install gems dependencies of puppet-opendaylight via Bundler
gem install bundler
echo export PATH="\\$PATH:/usr/local/bin" >> "$HOME/.bashrc"
# RVM's loaded functions print lots of output at this step, silence them
set +x
pushd "$WORKSPACE/puppet"
set -x
bundle install
bundle update

# Execute set of tests passed as param from job
bundle exec rake "$TEST_SUITE"
