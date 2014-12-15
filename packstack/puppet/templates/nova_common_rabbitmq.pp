
$private_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_SECRET'),
}
$public_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_PUBLIC'),
}

$nova_common_rabbitmq_cfg_storage_host = hiera('CONFIG_STORAGE_HOST')
$ipa_install = hiera('CONFIG_IPA_INSTALL')
$amqp_enable_ssl = hiera('CONFIG_AMQP_ENABLE_SSL')
$amqp_ssl_self_signed = hiera('CONFIG_AMQP_SSL_SELF_SIGNED','n')

if ($ipa_install == 'y' and
    $amqp_enable_ssl and
    $amqp_ssl_self_signed  == 'y') {
  $kombu_ssl_ca_certs = '/etc/ipa/ca.crt'
  $kombu_ssl_keyfile = '/etc/pki/tls/private/ssl_amqp_nova.key'
  $kombu_ssl_certfile = '/etc/pki/tls/certs/ssl_amqp_nova.crt'

  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'nova',
    group   => 'nova',
    require => Package['nova-common'],
  }

  File[$files_to_set_owner] ~> Service <||>

  class { 'nova':
    glance_api_servers => "${nova_common_rabbitmq_cfg_storage_host}:9292",
    rabbit_host        => hiera('CONFIG_AMQP_HOST'),
    rabbit_port        => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl     => $amqp_enable_ssl,
    rabbit_userid      => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password    => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    verbose            => true,
    debug              => hiera('CONFIG_DEBUG_MODE'),
    nova_public_key    => $public_key,
    nova_private_key   => $private_key,
    kombu_ssl_ca_certs => $kombu_ssl_ca_certs,
    kombu_ssl_keyfile  => $kombu_ssl_keyfile,
    kombu_ssl_certfile => $kombu_ssl_certfile,
  }
} else {
  class { 'nova':
    glance_api_servers => "${nova_common_rabbitmq_cfg_storage_host}:9292",
    rabbit_host        => hiera('CONFIG_AMQP_HOST'),
    rabbit_port        => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl     => $amqp_enable_ssl,
    rabbit_userid      => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password    => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    verbose            => true,
    debug              => hiera('CONFIG_DEBUG_MODE'),
    nova_public_key    => $public_key,
    nova_private_key   => $private_key,
  }
}
