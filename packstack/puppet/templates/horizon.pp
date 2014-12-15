include packstack::apache_common

$keystone_host = hiera('CONFIG_CONTROLLER_HOST')

$horizon_packages = ['python-memcached', 'python-netaddr']

package { $horizon_packages:
  ensure => present,
  notify => Class['horizon'],
}

$is_django_debug = hiera('CONFIG_DEBUG_MODE') ? {
  true  => 'True',
  false => 'False',
}

$controller_host = hiera('CONFIG_CONTROLLER_HOST')
$ipa_install = hiera('CONFIG_IPA_INSTALL')
$ipa_host = hiera('CONFIG_IPA_HOST',undef)

$is_horizon_ssl = hiera('CONFIG_HORIZON_SSL')

if $is_horizon_ssl == true {
  $horizon_cert = '/etc/pki/tls/certs/ssl_ps_server.crt'
  $horizon_key = '/etc/pki/tls/private/ssl_ps_server.key'

  if $ipa_install {
    $horizon_ca = '/etc/ipa/ca.crt'
  } else {
    $horizon_ca = '/etc/pki/tls/certs/ssl_ps_chain.crt'

    file {'/etc/pki/tls/certs/ps_generate_ssl_certs.ssh':
      ensure  => present,
      content => template('packstack/ssl/generate_ssl_certs.sh.erb'),
      mode    => '0755',
    }

    exec {'/etc/pki/tls/certs/ps_generate_ssl_certs.ssh':
      require => File['/etc/pki/tls/certs/ps_generate_ssl_certs.ssh'],
      notify  => Service['httpd'],
      before  => Class['horizon'],
    } ->
    exec { 'nova-novncproxy-restart':
      # TODO: FIXME: this definetly does not belong to horizon.pp
      # ps_generate_ssl_certs.ssh is generating ssl certs for nova-novncproxy
      # so openstack-nova-novncproxy should be restarted.
      path      => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
      command   => 'systemctl restart openstack-nova-novncproxy.service',
      logoutput => 'on_failure',
    }
  }

  $files_to_set_owner = [ $horizon_cert, $horizon_key ]
  file { $files_to_set_owner:
    owner   => 'apache',
    group   => 'apache',
    require => Package['httpd'],
    notify  => Service['httpd'],
  }

  apache::listen { '443': }

}

if ($ipa_install and ($ipa_host == $controller_host)) {
  $configure_apache = false
  $conf_template = '/etc/httpd/conf/httpd.conf'
} else {
  $configure_apache = true
  $conf_template = undef
}

class{ 'apache':
  purge_configs => false,
  default_mods => true,
  default_confd_files => true,
  conf_template => $conf_template,
}

class {'horizon':
  secret_key            => hiera('CONFIG_HORIZON_SECRET_KEY'),
  keystone_url          => "http://${keystone_host}:5000/v2.0",
  keystone_default_role => '_member_',
  server_aliases       => [hiera('CONFIG_CONTROLLER_HOST'), "$::fqdn", 'localhost'],
  allowed_hosts        => '*',
  hypervisor_options   => {'can_set_mount_point' => false, },
  compress_offline     => false,
  django_debug         => $is_django_debug,
  file_upload_temp_dir => '/var/tmp',
  listen_ssl           => hiera('CONFIG_HORIZON_SSL'),
  horizon_cert         => $horizon_cert,
  horizon_key          => $horizon_key,
  horizon_ca           => $horizon_ca,
  neutron_options      => {
    'enable_lb'        => hiera('CONFIG_HORIZON_NEUTRON_LB'),
    'enable_firewall'  => hiera('CONFIG_HORIZON_NEUTRON_FW'),
  },
  configure_apache => $configure_apache,
  notify => Service['httpd'],
}

class { 'memcached': }

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
