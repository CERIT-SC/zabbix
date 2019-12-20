class zabbix::role::pbs_node (
  String $name_of_check = "pbs",
  String $command,
) {

  $pbs_check_zabbix = @(END)
  HostMetadata = pbs_node
  UserParameter=<%= $name_of_check %>, <%= $command %>
  END

  file { '/etc/zabbix/zabbix_agentd.d':
     ensure  => 'directory',
     require => Class['zabbix::role::agent'],
  }

  file { 'PBS check enable':
     ensure  => "present",
     content => inline_epp($pbs_check_zabbix, {'name' => $name_of_check, 'command' => $command })
     path    => '/etc/zabbix/zabbix_agentd.d/pbs.conf',
     notify  => Service['zabbix-agent'],
     require => File['/etc/zabbix/zabbix_agentd.d'],
  }
}
