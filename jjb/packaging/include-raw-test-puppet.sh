#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Adapted from puppet-opendaylight/Vagrantfile
# https://github.com/dfarrell07/puppet-opendaylight/blob/master/Vagrantfile

# Update Int/Pack's puppet-opendaylight submodule to latest master
git submodule update --remote

# Install system-wide dependencies
yum install -y ruby-devel gcc-c++ zlib-devel patch redhat-rpm-config make rubygems

# Install RVM to help build recent version of Ruby
# The ruby_dep gem requires >=2.2.5, 2.0.0 is the latest pre-packaged for CentOS
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -L get.rvm.io | bash -s stable
# Expected by RVM, seems required to make RVM functions (`rvm use`) available
echo source /etc/profile.d/rvm.sh >> $HOME/.bashrc
rvm install 2.4.0
ruby --version
# This has to be done as a login shell to get rvm fns
# https://rvm.io/support/faq#what-shell-login-means-bash-l
# http://superuser.com/questions/306530/run-remote-ssh-command-with-full-login-shell
bash -lc "rvm use 2.4.0 --default"
ruby --version

# Install gems dependencies of puppet-opendaylight via Bundler
gem install bundler
echo export PATH=\\$PATH:/usr/local/bin >> $HOME/.bashrc
pushd $WORKSPACE/packaging/puppet/puppet-opendaylight
bundle install
bundle update

# Quick+important tests: Linting, rspec and Beaker on CentOS container tests
bundle exec rake sanity
