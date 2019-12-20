class zabbix::role::pbs_node (
  String $name_of_check = "pbs",
  String $command,
) {

  file { '/etc/zabbix/zabbix_agentd.d':
     ensure  => 'directory',
     require => File['zabbix-agent-config'],
  }

  file { 'PBS check enable':
     ensure  => "present",
     content => inline_epp("HostMetadata=pbs_node\nUserParameter=$name_of_check,$command", {'name' => $name_of_check, 'command' => $command }),
     path    => '/etc/zabbix/zabbix_agentd.d/pbs.conf',
     notify  => Service['zabbix-agent'],
  }
}
