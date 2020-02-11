class zabbix (
  Boolean $server                  = false,
  String  $server_ip               = "127.0.0.1",
  String  $mysql_password          = "zabbix",
  Hash    $auto_registry           = {},
  String  $api_key                 = "",
  Hash    $templates               = {},
  Boolean $daily_report            = false,
  String  $smtp_server             = "localhost.localdomain",
  String  $smtp_port               = "25",
  String  $email_to                = "example@example.com",
  Hash    $user_parameters         = {},
  Array   $hostmetadata            = [],
  Boolean $letsencrypt             = false,
) {
  if ($server == true) {
     include zabbix::role::server
  } else {
     include zabbix::role::agent
  }
}
