
$private_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_SECRET'),
}
$public_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_PUBLIC'),
}

$nova_common_rabbitmq_cfg_storage_host = hiera('CONFIG_STORAGE_HOST_URL')
$config_horizon_ssl = hiera('CONFIG_HORIZON_SSL')

$vncproxy_protocol = $config_horizon_ssl ? {
  true    => 'https',
  false   => 'http',
  default => 'http',
}

class { 'nova':
  glance_api_servers => "${nova_common_rabbitmq_cfg_storage_host}:9292",
  rabbit_host        => hiera('CONFIG_AMQP_HOST_URL'),
  rabbit_port        => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl     => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid      => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password    => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  verbose            => true,
  debug              => hiera('CONFIG_DEBUG_MODE'),
  nova_public_key    => $public_key,
  nova_private_key   => $private_key,
  vncproxy_host      => hiera('CONFIG_CONTROLLER_HOST'),
  vncproxy_protocol  => $vncproxy_protocol,
}
