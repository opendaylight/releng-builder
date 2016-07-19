package { [
    'build-essential',
    'fakeroot',
    'debhelper',
    'autoconf',
    'automake',
    'libssl-dev',
    'bzip2',
    'openssl',
    'graphviz',
    'python-all',
    'procps',
    'python-qt4',
    'python-zopeinterface',
    'python-twisted-conch',
    'libtool',
    "linux-headers-${::releaseversion}",
    'dkms',
  ]:
  ensure => present,
}

vcsrepo { '/root/ovs':
  ensure   => present,
  provider => git,
  source   => 'https://github.com/pritesh/ovs.git',
  revision => 'nsh-v8',
}


