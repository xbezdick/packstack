$sahara_cfg_sahara_db_pw = hiera('CONFIG_SAHARA_DB_PW')
$sahara_cfg_sahara_mariadb_host = hiera('CONFIG_MARIADB_HOST_URL')

$sahara_cfg_config_neutron_install = hiera('CONFIG_NEUTRON_INSTALL')

$sahara_cfg_controller_host = hiera('CONFIG_CONTROLLER_HOST')
class { 'sahara':
  database_connection =>
    "mysql://sahara:${sahara_cfg_sahara_db_pw}@${sahara_cfg_sahara_mariadb_host}/sahara",
  verbose             => true,
  debug               => hiera('CONFIG_DEBUG_MODE'),
  os_username         => 'admin',
  os_password         => hiera('CONFIG_KEYSTONE_ADMIN_PW'),
  os_tenant_name      => 'admin',
  os_auth_url         => "http://${sahara_cfg_controller_host}:5000/v2.0",
  identity_url        => "http://${sahara_cfg_controller_host}:35357/",
  use_neutron         => ($sahara_cfg_config_neutron_install == 'y'),
  service_host        => hiera('CONFIG_SAHARA_HOST'),
}
