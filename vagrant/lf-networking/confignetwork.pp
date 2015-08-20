# make system modifications to handle being on a private Rackspace network

# configure nameservers for domains
case $::subdomain {
  /^dfw\./: {
    $NS1 = '72.3.128.241'
    $NS2 = '72.3.128.240'
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
    $NS1 = '173.203.4.9'
    $NS2 = '173.203.4.8'
    $router = '10.30.32.1'
  }
  default: {
    fail("Unrecognized subdomain ${::subdomain}")
  }
}

# dnsmasq
class { 'dnsmasq':
  domain        => $::subdomain,
  expand_hosts  => true,
  domain_needed => true,
}

# can only have one NS per handled domain because of how
# the puppet module is built
dnsmasq::dnsserver { 'linux-foundation.org':
  domain => 'linux-foundation.org',
  ip     => '172.17.192.30',
}

dnsmasq::dnsserver { 'opendaylight.org':
  domain => 'opendaylight.org',
  ip     => '172.17.192.30',
}

dnsmasq::dnsserver { 'odlforge.org':
  domain => 'odlforge.org',
  ip     => '172.17.192.30',
}

# fix the resolver
file { '/etc/resolv.conf':
  content => "search ${::subdomain}
nameserver 127.0.0.1
nameserver ${NS1}
nameserver ${NS2}
options timeout:2
"
}

# set routing
case $::osfamily {
  'RedHat': {
    file { '/etc/sysconfig/network-scripts/route-eth0':
      content => "default via ${router} dev eth0"
  }
  'Ubuntu': {
    file { '/etc/network/if-up.d/0000routing':
      content => "ip route default via ${router} dev eth0"
    }
  }
}
