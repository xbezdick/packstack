$manila_network_type = hiera('CONFIG_MANILA_NETWORK_TYPE')

define packstack::manila::network ($backend_name = $name) {

  if ($::manila_network_type == 'neutron'){
    class { '::manila::network::neutron':
      neutron_admin_password     => hiera('CONFIG_NEUTRON_KS_PW'),
      neutron_admin_tenant_name  => 'services',
    }
  }
  elsif ($::manila_network_type == 'neutron-single-network'){
    manila::network::neutron_single_network{ $backend_name:
      neutron_net_id    => hiera('CONFIG_MANILA_NETWORK_NEUTRONSINGLE_NET_ID'),
      neutron_subnet_id => hiera('CONFIG_MANILA_NETWORK_NEUTRONSINGLE_SUBNET_ID')
    }
  }
  elsif ($::manila_network_type == 'nova-network'){
    manila::network::nova_network{ $backend_name: }
  }
  elsif ($::manila_network_type == 'nova-single-network'){
    manila::network::nova_single_network{ $backend_name:
      nova_single_network_plugin_net_id => hiera('CONFIG_MANILA_NETWORK_NOVANET_NET_ID')
    }
  }
  elsif ($::manila_network_type == 'standalone'){
    manila::network::standalone{ $backend_name:
      standalone_network_plugin_gateway           => hiera('CONFIG_MANILA_NETWORK_STANDALONE_GATEWAY'),
      standalone_network_plugin_mask              => hiera('CONFIG_MANILA_NETWORK_STANDALONE_NETMASK'),
      standalone_network_plugin_segmentation_id   => hiera('CONFIG_MANILA_NETWORK_STANDALONE_SEG_ID'),
      standalone_network_plugin_allowed_ip_ranges => hiera('CONFIG_MANILA_NETWORK_STANDALONE_IP_RANGE'),
      standalone_network_plugin_ip_version        => hiera('CONFIG_MANILA_NETWORK_STANDALONE_IP_VERSION'),
    }
  }
}
