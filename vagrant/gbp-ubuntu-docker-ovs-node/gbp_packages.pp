package { [
  'software-properties-common',
  'python-software-properties',
  'python-pip',
  'python-virtualenv',
  'git-core',
  'git',
  'curl',
  'bridge-utils']:
  ensure => present,
}
