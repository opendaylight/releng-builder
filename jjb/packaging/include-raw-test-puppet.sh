#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Adapted from puppet-opendaylight/Vagrantfile
# https://github.com/dfarrell07/puppet-opendaylight/blob/master/Vagrantfile

# Install system-wide dependencies
# TODO: Are all of these still needed?
sudo yum install -y ruby-devel gcc-c++ zlib-devel patch redhat-rpm-config make rubygems

# Install RVM to help build recent version of Ruby
# The ruby_dep gem requires >=2.2.5, 2.0.0 is the latest pre-packaged for CentOS
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -L get.rvm.io | bash -s stable
# Expected by RVM, seems required to make RVM functions (`rvm use`) available
# shellcheck disable=SC1090
source "$HOME/.rvm/scripts/rvm"
rvm install 2.4.0
ruby --version
# This has to be done as a login shell to get rvm fns
# https://rvm.io/support/faq#what-shell-login-means-bash-l
# http://superuser.com/questions/306530/run-remote-ssh-command-with-full-login-shell
bash -lc "rvm use 2.4.0 --default"
ruby --version

# Install gems dependencies of puppet-opendaylight via Bundler
gem install bundler
echo export PATH="\\$PATH:/usr/local/bin" >> "$HOME/.bashrc"
pushd "$WORKSPACE/puppet"
bundle install
bundle update

# Execute set of tests passed as param from job
bundle exec rake "$TEST_SUITE"
