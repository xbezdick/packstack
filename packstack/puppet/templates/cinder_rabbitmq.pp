$cinder_rab_cfg_cinder_db_pw = hiera('CONFIG_CINDER_DB_PW')
$cinder_rab_cfg_mariadb_host = hiera('CONFIG_MARIADB_HOST_URL')

$kombu_ssl_ca_certs = hiera('CONFIG_SSL_CACERT_FILE')
$kombu_ssl_keyfile = hiera('CONFIG_CINDER_SSL_KEY', undef)
$kombu_ssl_certfile = hiera('CONFIG_CINDER_SSL_CERT', undef)

if $kombu_ssl_keyfile {
  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'cinder',
    group   => 'cinder',
    require => Class['cinder'],
    notify  => Service['cinder-api'],
  }
}

class { '::cinder':
  rabbit_host         => hiera('CONFIG_AMQP_HOST_URL'),
  rabbit_port         => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl      => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid       => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password     => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  database_connection => "mysql://cinder:${cinder_rab_cfg_cinder_db_pw}@${cinder_rab_cfg_mariadb_host}/cinder",
  verbose             => true,
  debug               => hiera('CONFIG_DEBUG_MODE'),
  kombu_ssl_ca_certs  => $kombu_ssl_ca_certs,
  kombu_ssl_keyfile   => $kombu_ssl_keyfile,
  kombu_ssl_certfile  => $kombu_ssl_certfile,
}
