$trove_rabmq_cfg_trove_db_pw = hiera('CONFIG_TROVE_DB_PW')
$trove_rabmq_cfg_mariadb_host = hiera('CONFIG_MARIADB_HOST_URL')
$trove_rabmq_cfg_controller_host = hiera('CONFIG_KEYSTONE_HOST_URL')

$kombu_ssl_ca_certs = hiera('CONFIG_SSL_CACERT_FILE')
$kombu_ssl_keyfile = hiera('CONFIG_TROVE_SSL_KEY', undef)
$kombu_ssl_certfile = hiera('CONFIG_TROVE_SSL_CERT', undef)

if $kombu_ssl_keyfile {
  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'trove',
    group   => 'trove',
    require => Package['openstack-trove-common'],
  }
  File[$files_to_set_owner] ~> Service<||>
}


class { '::trove':
  rpc_backend                  => 'trove.openstack.common.rpc.impl_kombu',
  rabbit_host                  => hiera('CONFIG_AMQP_HOST_URL'),
  rabbit_use_ssl               => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_port                  => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_userid                => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password              => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  database_connection          => "mysql://trove:${trove_rabmq_cfg_trove_db_pw}@${trove_rabmq_cfg_mariadb_host}/trove",
  nova_proxy_admin_user        => hiera('CONFIG_TROVE_NOVA_USER'),
  nova_proxy_admin_tenant_name => hiera('CONFIG_TROVE_NOVA_TENANT'),
  nova_proxy_admin_pass        => hiera('CONFIG_TROVE_NOVA_PW'),
  nova_compute_url             => "http://${trove_rabmq_cfg_controller_host}:8774/v2",
  cinder_url                   => "http://${trove_rabmq_cfg_controller_host}:8776/v1",
  swift_url                    => "http://${trove_rabmq_cfg_controller_host}:8080/v1/AUTH_",
  use_neutron                  => hiera('CONFIG_NEUTRON_INSTALL'),
  kombu_ssl_ca_certs           => $kombu_ssl_ca_certs,
  kombu_ssl_keyfile            => $kombu_ssl_keyfile,
  kombu_ssl_certfile           => $kombu_ssl_certfile,
}
