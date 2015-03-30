
$private_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_SECRET'),
}
$public_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_PUBLIC'),
}

$nova_common_qpid_cfg_storage_host = hiera('CONFIG_STORAGE_HOST_URL')
$config_horizon_ssl = hiera('CONFIG_HORIZON_SSL')

$vncproxy_protocol = $config_horizon_ssl ? {
  true    => 'https',
  false   => 'http',
  default => 'http',
}

class { 'nova':
  glance_api_servers => "${nova_common_qpid_cfg_storage_host}:9292",
  qpid_hostname      => hiera('CONFIG_AMQP_HOST_URL'),
  qpid_username      => hiera('CONFIG_AMQP_AUTH_USER'),
  qpid_password      => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  rpc_backend        => 'nova.openstack.common.rpc.impl_qpid',
  qpid_port          => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  qpid_protocol      => hiera('CONFIG_AMQP_PROTOCOL'),
  verbose            => true,
  debug              => hiera('CONFIG_DEBUG_MODE'),
  nova_public_key    => $public_key,
  nova_private_key   => $private_key,
  vncproxy_host      => hiera('CONFIG_CONTROLLER_HOST'),
  vncproxy_protocol  => $vncproxy_protocol,
}
