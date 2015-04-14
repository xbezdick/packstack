$kombu_ssl_ca_certs = hiera('CONFIG_SSL_CACERT_FILE')
$kombu_ssl_keyfile = hiera('CONFIG_SAHARA_SSL_KEY', undef)
$kombu_ssl_certfile = hiera('CONFIG_SAHARA_SSL_CERT', undef)

if $kombu_ssl_keyfile {
  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'sahara',
    group   => 'sahara',
    require => Package['openstack-sahara'],
  }
  File[$files_to_set_owner] ~> Service<||>
}

class { '::sahara::notify::rabbitmq':
  rabbit_host     => hiera('CONFIG_AMQP_HOST_URL'),
  rabbit_port     => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl  => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid   => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  kombu_ssl_ca_certs => $kombu_ssl_ca_certs,
  kombu_ssl_keyfile  => $kombu_ssl_keyfile,
  kombu_ssl_certfile => $kombu_ssl_certfile,
}
