class zabbix (
  Boolean $server = false,
) {
  if ($server == true) {
     include zabbix::role::server
  } esle {
     include zabbix::role::agent
  }
}
