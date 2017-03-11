
#include docker
class { 'docker':
  tcp_bind         => 'tcp://0.0.0.0:5555',
  extra_parameters => '--bip=10.250.0.254/24',
}

if $operatingsystem == 'Ubuntu' and versioncmp($operatingsystemrelease, '16.04') >= 0 {
 # Sets the new systemd as default service provider on Ubuntu 16.04 and higher.
 # Works around upstart being used by Puppet.
 # See also: https://bugs.launchpad.net/ubuntu/+source/puppet/+bug/1570472
 Service {
    provider => systemd
 }
}
