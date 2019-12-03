class zabbix::role::agent {

   package {"zabbix-agent":
       ensure => "present",
   }

   file {'zabbix-agent-config':
       ensure  => 'present',
       path    => '/etc/zabbix/zabbix_agentd.conf',
       content => epp('zabbix/zabbix_agent_config.epp', { "server_ip" => $::zabbix::server_ip }),
       require => Package['zabbix-agent'],
       notify  => Service['zabbix-agent'],
   }


   service {'zabbix-agent':
      ensure  => 'running',
      enable  => true,
      require => [ File['zabbix-agent-config'], Package['zabbix-agent'] ],
   }
}
