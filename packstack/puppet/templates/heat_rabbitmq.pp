$heat_rabbitmq_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')
$heat_rabbitmq_cfg_heat_db_pw = hiera('CONFIG_HEAT_DB_PW')
$heat_rabbitmq_cfg_mariadb_host = hiera('CONFIG_MARIADB_HOST')

$ipa_install = hiera('CONFIG_IPA_INSTALL')
$amqp_enable_ssl = hiera('CONFIG_AMQP_ENABLE_SSL')
$amqp_ssl_self_signed = hiera('CONFIG_AMQP_SSL_SELF_SIGNED','n')

if ($ipa_install == 'y' and
    $amqp_enable_ssl and
    $amqp_ssl_self_signed  == 'y') {
  $kombu_ssl_ca_certs = '/etc/ipa/ca.crt'
  $kombu_ssl_keyfile = '/etc/pki/tls/private/ssl_amqp_heat.key'
  $kombu_ssl_certfile = '/etc/pki/tls/certs/ssl_amqp_heat.crt'

  $files_to_set_owner = [ $kombu_ssl_keyfile, $kombu_ssl_certfile ]
  file { $files_to_set_owner:
    owner   => 'heat',
    group   => 'heat',
    require => Package['openstack-heat-common'],
  }
  File[$files_to_set_owner] ~> Service<||>

  class { 'heat':
    keystone_host       => $heat_rabbitmq_cfg_ctrl_host,
    keystone_password   => hiera('CONFIG_HEAT_KS_PW'),
    auth_uri            => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
    keystone_ec2_uri    => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
    rpc_backend         => 'heat.openstack.common.rpc.impl_kombu',
    rabbit_host         => hiera('CONFIG_AMQP_HOST'),
    rabbit_port         => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl      => $amqp_enable_ssl,
    rabbit_userid       => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password     => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    verbose             => true,
    debug               => hiera('CONFIG_DEBUG_MODE'),
    database_connection => "mysql://heat:${heat_rabbitmq_cfg_heat_db_pw}@${heat_rabbitmq_cfg_mariadb_host}/heat",
    kombu_ssl_ca_certs  => $kombu_ssl_ca_certs,
    kombu_ssl_keyfile   => $kombu_ssl_keyfile,
    kombu_ssl_certfile  => $kombu_ssl_certfile,
  }
} else {
  class { 'heat':
    keystone_host       => $heat_rabbitmq_cfg_ctrl_host,
    keystone_password   => hiera('CONFIG_HEAT_KS_PW'),
    auth_uri            => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
    keystone_ec2_uri    => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
    rpc_backend         => 'heat.openstack.common.rpc.impl_kombu',
    rabbit_host         => hiera('CONFIG_AMQP_HOST'),
    rabbit_port         => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl      => $amqp_enable_ssl,
    rabbit_userid       => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password     => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    verbose             => true,
    debug               => hiera('CONFIG_DEBUG_MODE'),
    database_connection => "mysql://heat:${heat_rabbitmq_cfg_heat_db_pw}@${heat_rabbitmq_cfg_mariadb_host}/heat",
  }
}
