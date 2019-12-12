class zabbix (
  Boolean $server                  = false,
  String  $server_ip               = "127.0.0.1",
  String  $mysql_password          = "zabbix",
  Array   $auto_registry_templates = [],
  String  $api_key                 = "",
) {
  if ($server == true) {
     include zabbix::role::server
  } else {
     include zabbix::role::agent
  }
}
