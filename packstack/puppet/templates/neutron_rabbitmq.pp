$ipa_install = hiera('CONFIG_IPA_INSTALL')
$amqp_enable_ssl = hiera('CONFIG_AMQP_ENABLE_SSL')
$amqp_ssl_self_signed = hiera('CONFIG_AMQP_SSL_SELF_SIGNED','n')

if ($ipa_install == 'y' and
    $amqp_enable_ssl and
    $amqp_ssl_self_signed  == 'y') {
  $kombu_ssl_ca_certs = '/etc/ipa/ca.crt'
  $kombu_ssl_keyfile = '/etc/pki/tls/private/ssl_amqp_neutron.key'
  $kombu_ssl_certfile = '/etc/pki/tls/certs/ssl_amqp_neutron.crt'

  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'neutron',
    group   => 'neutron',
    require => Class['neutron'],
  }

  File[$files_to_set_owner] ~> Service <||>

  class { 'neutron':
    rabbit_host           => hiera('CONFIG_AMQP_HOST'),
    rabbit_port           => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl        => $amqp_enable_ssl,
    rabbit_user           => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password       => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    core_plugin           => hiera('CONFIG_NEUTRON_CORE_PLUGIN'),
    allow_overlapping_ips => true,
    service_plugins       => hiera_array('SERVICE_PLUGINS'),
    verbose               => true,
    debug                 => hiera('CONFIG_DEBUG_MODE'),
    kombu_ssl_ca_certs    => $kombu_ssl_ca_certs,
    kombu_ssl_keyfile     => $kombu_ssl_keyfile,
    kombu_ssl_certfile    => $kombu_ssl_certfile,
  }
} else {
  class { 'neutron':
    rabbit_host           => hiera('CONFIG_AMQP_HOST'),
    rabbit_port           => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl        => $amqp_enable_ssl,
    rabbit_user           => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password       => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    core_plugin           => hiera('CONFIG_NEUTRON_CORE_PLUGIN'),
    allow_overlapping_ips => true,
    service_plugins       => hiera_array('SERVICE_PLUGINS'),
    verbose               => true,
    debug                 => hiera('CONFIG_DEBUG_MODE'),
  }
}
