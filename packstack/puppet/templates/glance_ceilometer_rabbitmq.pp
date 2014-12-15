$ipa_install = hiera('CONFIG_IPA_INSTALL')
$amqp_enable_ssl = hiera('CONFIG_AMQP_ENABLE_SSL')
$amqp_ssl_self_signed = hiera('CONFIG_AMQP_SSL_SELF_SIGNED','n')

if ($ipa_install == 'y' and
    $amqp_enable_ssl and
    $amqp_ssl_self_signed  == 'y') {

  $kombu_ssl_ca_certs = '/etc/ipa/ca.crt'
  $kombu_ssl_keyfile = '/etc/pki/tls/private/ssl_amqp_glance.key'
  $kombu_ssl_certfile = '/etc/pki/tls/certs/ssl_amqp_glance.crt'

  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'glance',
    group   => 'glance',
    require => Class['glance::notify::rabbitmq'],
    notify  => Service['glance-api'],
  }

  class { 'glance::notify::rabbitmq':
    rabbit_host        => hiera('CONFIG_AMQP_HOST'),
    rabbit_port        => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl     => $amqp_enable_ssl,
    rabbit_userid      => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password    => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    kombu_ssl_ca_certs => $kombu_ssl_ca_certs,
    kombu_ssl_keyfile  => $kombu_ssl_keyfile,
    kombu_ssl_certfile => $kombu_ssl_certfile,
  }

} else {

  class { 'glance::notify::rabbitmq':
    rabbit_host      => hiera('CONFIG_AMQP_HOST'),
    rabbit_port      => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl   => $amqp_enable_ssl,
    rabbit_userid    => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password  => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  }

}
