include ::packstack::apache_common

$keystone_host = hiera('CONFIG_KEYSTONE_HOST_URL')

$horizon_packages = ['python-memcached', 'python-netaddr']

package { $horizon_packages:
  ensure => present,
  notify => Class['horizon'],
}

$is_django_debug = hiera('CONFIG_DEBUG_MODE') ? {
  true  => 'True',
  false => 'False',
}

$bind_host = hiera('CONFIG_IP_VERSION') ? {
  'ipv6' => '::0',
  'ipv4' => '0.0.0.0',
}

class {'::horizon':
  secret_key            => hiera('CONFIG_HORIZON_SECRET_KEY'),
  keystone_url          => "http://${keystone_host}:5000/v2.0",
  keystone_default_role => '_member_',
  server_aliases        => [hiera('CONFIG_CONTROLLER_HOST'), $::fqdn, 'localhost'],
  allowed_hosts         => '*',
  hypervisor_options    => {'can_set_mount_point' => false, },
  compress_offline      => false,
  django_debug          => $is_django_debug,
  file_upload_temp_dir  => '/var/tmp',
  listen_ssl            => hiera('CONFIG_HORIZON_SSL'),
  horizon_cert          => hiera('CONFIG_HORIZON_SSL_CERT', undef),
  horizon_key           => hiera('CONFIG_HORIZON_SSL_KEY', undef),
  horizon_ca            => hiera('CONFIG_HORIZON_SSL_CACERT', undef),
  neutron_options       => {
    'enable_lb'       => hiera('CONFIG_HORIZON_NEUTRON_LB'),
    'enable_firewall' => hiera('CONFIG_HORIZON_NEUTRON_FW'),
  },
}

if hiera('CONFIG_HORIZON_SSL') {
  apache::listen { '443': }
}

class { '::memcached':
  listen_ip => $bind_host,
}

$firewall_port = hiera('CONFIG_HORIZON_PORT')

firewall { "001 horizon ${firewall_port}  incoming":
  proto  => 'tcp',
  dport  => [$firewall_port],
  action => 'accept',
}

if str2bool($::selinux) {
  selboolean{ 'httpd_can_network_connect':
    value      => on,
    persistent => true,
  }
}
