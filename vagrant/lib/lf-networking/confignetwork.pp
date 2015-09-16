# make system modifications to handle being on a private Rackspace network

# lint:ignore:80chars
notice ("Operating system detected is: '${::operatingsystem} ${::operatingsystemrelease}'")
# lint:endignore
notice ("Subdomain being used is: '${::subdomain}'")

# configure nameservers for domains
case $::subdomain {
  /^dfw\./: {
    $ns1 = '72.3.128.241'
    $ns2 = '72.3.128.240'
    case $::subdomain {
      /opendaylight/: {
        $router = '10.30.11.1'
      }
      /odlforge/: {
        $router = '10.30.12.1'
      }
      default: {
        fail("Unrecognized subdomain ${::subdomain}")
      }
    }
  }
  /^ord\./: {
    $ns1 = '173.203.4.9'
    $ns2 = '173.203.4.8'
    $router = '10.30.32.1'
  }
  default: {
    fail("Unrecognized subdomain ${::subdomain}")
  }
}

# dnsmasq
class { 'dnsmasq': }

# Setup dnsmasq special domain handlers
dnsmasq::conf { 'LF-ns1':
  ensure  => present,
  content => 'server=/linux-foundation.org/172.17.192.30',
}

dnsmasq::conf { 'LF-ns2':
  ensure  => present,
  content => 'server=/linux-foundation.org/172.17.192.31',
}

dnsmasq::conf { 'ODL-ns1':
  ensure  => present,
  content => 'server=/opendaylight.org/172.17.192.30',
}

dnsmasq::conf { 'ODL-ns2':
  ensure  => present,
  content => 'server=/opendaylight.org/172.17.192.31',
}

dnsmasq::conf { 'ODLForge-ns1':
  ensure  => present,
  content => 'server=/odlforge.org/172.17.192.30',
}

dnsmasq::conf { 'ODLForge-ns2':
  ensure  => present,
  content => 'server=/odlforge.org/172.17.192.31',
}

# fix the resolver
file { '/etc/resolv.conf':
  content => "search ${::subdomain}
nameserver 127.0.0.1
nameserver ${ns1}
nameserver ${ns2}
options timeout:2
",
}

file { '/etc/cloud/cloud.cfg.d/00_lf_resolv.cfg':
  content => "#cloud-config

manage_resolv_conf: true

resolv_conf:
  nameservers: ['127.0.0.1', '${ns1}', '${ns2}']
  searchdomains:
    - ${::subdomain}
  options:
    timeout: 2
",
}

file_line { 'add_resolver':
  path  => '/etc/cloud/cloud.cfg.d/10_rackspace.cfg',
  line  => ' - resolv_conf',
  after => ' - update_etc_hosts',
}

# OS specific configuration
case $::operatingsystem {
  'CentOS', 'Fedora', 'RedHat': {
    file { '/etc/sysconfig/network-scripts/route-eth0':
      content => "default via ${router} dev eth0",
    }

    # disable the DNS peerage so that our resolv.conf doesn't
    # get destroyed
    file_line { 'disable_peerdns':
      path => '/etc/sysconfig/network',
      line => 'PEERDNS=no',
    }
  }
  'Ubuntu': {
    file { '/etc/network/if-up.d/0000routing':
      content => "#!/bin/sh\nip route add default via ${router} dev eth0",
      mode    => '0755',
    }
  }
  default: {
    notice ("${::operatingsystem} is not supported by this configuration")
  }
}
