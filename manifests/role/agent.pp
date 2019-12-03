class zabbix::role::agent {

   case $facts['operatingsystem'] {
      'Debian': {

         $parameters_for_config = {
             "path_to_log_file" => "/var/log/zabbix/zabbix_agentd.log",
             "server_ip"        => $::zabbix::server_ip,
          }

          package {"zabbix-agent":
             ensure => "present",
          }   
      }   

      'CentOS', 'RedHat': {

          $parameters_for_config = {
                                     "path_to_log_file" => "/var/log/zabbix/zabbix_agentd.log",
                                     "server_ip"        => $::zabbix::server_ip,
                                   }

          package {'zabbix-release':
             provider => 'rpm',
             ensure   => installed,
             source   => 'https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm',
          }   

          package {"zabbix-agent":
             ensure  => "present",
             require => Package['zabbix-release'],
          }   
      }   

      default: {
          fail("This OS is unsupported")
      }   
   }   

   file {'zabbix-agent-config':
       ensure  => 'present',
       path    => '/etc/zabbix/zabbix_agentd.conf',
       content => epp('zabbix/zabbix_agent_config.epp', $parameters_for_config), 
       require => Package['zabbix-agent'],
       notify  => Service['zabbix-agent'],
   }   


   service {'zabbix-agent':
      ensure  => 'running',
      enable  => true,
      require => [ File['zabbix-agent-config'], Package['zabbix-agent'] ],
   }   
}

