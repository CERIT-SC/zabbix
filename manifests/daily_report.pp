class zabbix::daily_report (
   String $email_to,
   String $smtp_server,
   String $smtp_port, 
) {

  package { 'net/smtp':
      ensure   => 'installed',
      provider => 'gem',
  }

  file { 'zabbix daily report script':
      path    => '/usr/local/bin/zabbix_daily_report.rb',
      content => epp('zabbix/daily_report.epp', { "email_to" => $email_to, "smtp_server" => $smtp_server, "smtp_port" => $smtp_port, "api_key" => $::zabbix::apiKey, "url" => "http://${::zabbix::server_ip}/zabbix/api_jsonrpc.php" }),
      ensure  => 'present',
  }  

  cron { 'cron to send daily report'
      command => '/usr/local/bin/zabbix_daily_report.rb > /dev/null',
      hour    => '0',
      minute  => '0',
      require => File['zabbix daily report script'],
  }
}
