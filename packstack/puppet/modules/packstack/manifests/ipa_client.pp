# == Define: packstack::ipa_client
#
# Full description of defined resource type packstack::ipa_client here
#
# === Parameters
#
# [*ipa_hostname*]
#
# [*ipa_domain*]
#
# [*ipa_server_hostname*]
#
# [*ipa_host_ip*]
#
# [*ipa_server_ip*]
#
# [*ipa_admin_install*]
#
# === Examples
#
# Provide some examples on how to use this type:
#
#   packstack::ipa_client { 'namevar':
#     basedir => '/tmp/src',
#   }
#
# === Authors
#
# Lukas Bezdicka <lbezdick@redhat.com>
#
# === Copyright
#
# Copyright 2014 Red Hat, Inc.
#
define packstack::ipa_client (
  $ipa_hostname,
  $ipa_domain,
  $ipa_server_hostname,
  $ipa_host_ip,
  $ipa_server_ip,
  $ipa_admin_install = true
) {

  $realm = upcase("${ipa_domain}")

  class { 'ipa':
    client      => true,
    domain      => $ipa_domain,
    realm       => $realm,
    ipaservers  => ["${ipa_server_hostname}.${ipa_domain}"],
    desc        => "${ipa_hostname}",
    clntpkg     => $::operatingsystem  ? {
      'Fedora' => 'freeipa-client',
      default  => 'ipa-client',
    },
    otp         => "${ipa_hostname}.packstack",
  }

  ipa::clientinstall { "$::fqdn":
    domain       => $ipa_domain,
    masterfqdn   => "${ipa_server_hostname}.${ipa_domain}",
    realm        => $realm,
    otp          => "${ipa_hostname}.packstack",
    mkhomedir    => false,
    fixedprimary => true,
  }

  # FIXME: hack around race condition in ::ipa
  exec { 'sssd-sleep':
    command => '/bin/sleep 5s',
    subscribe => Ipa::Clientinstall[$::fqdn],
    notify => Service['sssd'],
  }

  file { '/etc/hostname':
    content => "${::fqdn}",
  }

  if !($ipa_admin_install) {

    $configured_interface = inline_template("<%= scope.lookupvar('::interfaces').split(',').reject { |int|  ( scope.lookupvar('::ipaddress_' + int) != @ipa_host_ip ) }[0] -%>")

    # Ugly hack, we need clients to talk to DNS provided by IPA
    service { 'network':
      ensure => 'running',
      before => Class["ipa"],
    }

    file { '/etc/dhcp/dhclient.conf':
      ensure => 'present',
    }

    file_line { 'server-hosts-record':
      path    => '/etc/hosts',
      match   => "${ipa_server_ip} ${ipa_server_hostname}.${ipa_domain} ${ipa_server_hostname}.*",
      line    => "${ipa_server_ip} ${ipa_server_hostname}.${ipa_domain} ${ipa_server_hostname}",
      before  => Class['ipa'],
    }

    file_line { 'dhcp-force-ipa-dns':
      path    => '/etc/dhcp/dhclient.conf',
      match   => 'prepend domain-name-servers .*;',
      line    => "prepend domain-name-servers ${ipa_server_ip};",
      notify  => Service['network'],
      require => File['/etc/dhcp/dhclient.conf'],
    }

    file_line { "ifcfg-PEERDNS-no-${configured_interface}":
      path   => "/etc/sysconfig/network-scripts/ifcfg-${configured_interface}",
      match  => '^PEERDNS=.*',
      line   => 'PEERDNS="no"',
      notify => Service['network'],
    }

    file_line { "ifcfg-DNS1-no-${configured_interface}":
      path   => "/etc/sysconfig/network-scripts/ifcfg-${configured_interface}",
      match  => '^DNS1=.*',
      line   => "DNS1=${ipa_server_ip}",
      notify => Service['network'],
    }
  }
}
