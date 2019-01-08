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
sudo yum install -y ruby-devel gcc-c++ zlib-devel patch redhat-rpm-config make rubygems

# Install RVM to help build recent version of Ruby
# The ruby_dep gem requires >=2.2.5, 2.0.0 is the latest pre-packaged for CentOS
gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys \
  409B6B1796C275462A1703113804BB82D39DC0E3 \
  7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -L get.rvm.io | bash -s stable
# Expected by RVM, seems required to make RVM functions (`rvm use`) available
# Silence absurdly verbose rvm output by temporally not echoing commands
set +x
# Source line has a non-zero exit somewhere, that RVM doesn't mean to indicate
# a real failure, but causes our jobs to fail when fail-on-errors is enabled.
set +e
# shellcheck disable=SC1090
source "$HOME/.rvm/scripts/rvm"
set -e
rvm install 2.6.0
set -x
ruby --version
# This has to be done as a login shell to get rvm fns
# https://rvm.io/support/faq#what-shell-login-means-bash-l
# http://superuser.com/questions/306530/run-remote-ssh-command-with-full-login-shell
bash -lc "rvm use 2.6.0 --default"
ruby --version

# Update RubyGems using itself, as OS package may be old
# Ran into RubyGems 2.x installed by OS, 3.x required by Bundler in INTPAK-230
gem update --system

# Install gems dependencies of puppet-opendaylight via Bundler
gem install bundler
echo export PATH="\\$PATH:/usr/local/bin" >> "$HOME/.bashrc"
# RVM's loaded functions print lots of output at this step, silence them
set +x
pushd "$WORKSPACE/packaging-puppet"
set -x
bundle install
bundle update

# Execute set of tests passed as param from job
bundle exec rake "$TEST_SUITE"
