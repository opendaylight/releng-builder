
#include docker
class { 'docker':
  tcp_bind         => 'tcp://0.0.0.0:5555',
  extra_parameters => '--bip=10.250.0.254/24',
}
