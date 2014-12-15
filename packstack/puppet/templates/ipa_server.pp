$ipa_server_ip = hiera('CONFIG_IPA_HOST')

file_line { 'hosts-record':
  path    => '/etc/hosts',
  match   => "${ipa_server_ip} ${::fqdn} ${::hostname}.*",
  line    => "${ipa_server_ip} ${::fqdn} ${::hostname}",
  before  => Class['ipa'],
}

class { 'ipa':
  master  => true,
  domain  => 'packstack',
  realm   => 'PACKSTACK',
  dspw    => hiera('CONFIG_IPA_DM_PASSWORD'),
  adminpw => hiera('CONFIG_IPA_ADMIN_PASSWORD'),
  svrpkg  => $::operatingsystem  ? {
    'Fedora' => 'freeipa-server',
    default  => 'ipa-server',
  },
  dns     => true,
}

exec { 'restart-ipa-server-after-install':
  command      => '/usr/sbin/service ipa restart',
  refreshonly => true,
  subscribe    => Exec["serverinstall-${::fqdn}"],
}

Exec['restart-ipa-server-after-install'] -> Ipa::Hostadd<||>

