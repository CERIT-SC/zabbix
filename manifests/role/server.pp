class zabbix::role::server {

   case $facts['operatingsystem'] {
       'CentOS': {
           case $facts['operatingsystemmajrelease'] {
             '7': {
                package {'zabbix-release':
                    provider => 'rpm',
                    ensure   => "installed",
                    source   => 'https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm',
                }
                $_packages_to_install = ["zabbix-server-mysql", "zabbix-web-mysql", "zabbix-agent", "mariadb-server"]
              }
              '8': {
                package {'zabbix-release':
                    provider => 'rpm',
                    ensure   => "installed",
                    source   => 'https://repo.zabbix.com/zabbix/4.4/rhel/8/x86_64/zabbix-release-4.4-1.el8.noarch.rpm',
                }
                $_packages_to_install = ["zabbix-server-mysql", "zabbix-web-mysql", "zabbix-agent", "mariadb-server"]
              }
              default: {
                fail("This version of CentOS is unsupported")
              }
          }
       }
   }

   package { $_packages_to_install:
       ensure  => "installed",
       require => Package['zabbix-release'],
   }

   augeas { 'mariadb-disable-strict-mode':
      incl    => '/etc/my.cnf.d/mariadb-server.cnf',
      lens    => 'MYSQL.lns',
      changes => ["set target[ . = 'mariadb']/innodb_strict_mode 0",
                  "set target[ . = 'mariadb']/innodb_log_file_size 512M",
                  "set target[ . = 'mariadb']/innodb_page_size 64k",
                  "set target[ . = 'mariadb']/innodb_log_buffer_size 32M",
                  "set target[ . = 'mariadb']/innodb_default_row_format dynamic"],
      require => Package['mariadb-server'],
   }
   
   exec { 'create zabbix db':
       subscribe   => Package[$_packages_to_install],
       command     => '/bin/mysql -uroot -e "create database zabbix character set utf8 collate utf8_bin;"',
       refreshonly => true,
       require     => [Package[$_packages_to_install], Service['mariadb']],
   }

   exec { 'grant privileges on zabbix':
       subscribe   => Exec['create zabbix db'],
       command     => "/bin/mysql -uroot -e \"grant all privileges on zabbix.* to zabbix@localhost identified by \'${::zabbix::mysql_password}\'\";",
       refreshonly => true,
       require     => Exec['create zabbix db'],
   }

   #####
   ##### FIXME: https://support.zabbix.com/browse/ZBX-16757
   #####
   exec { 'import initial schema':
       subscribe   => Exec['grant privileges on zabbix'],
       command     => "/bin/zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | /bin/mysql zabbix -uzabbix -p${::zabbix::mysql_password}",
       refreshonly => true,
       require     => Exec['grant privileges on zabbix'],
   }


   file { 'zabbix config':
      ensure  => "present",
      path    => "/etc/zabbix/zabbix_server.conf",
      content => epp('zabbix/zabbix_server.conf.epp', { "password" => $::zabbix::mysql_password }),
      require => Package[$_packages_to_install],
   }
  
   file { "zabbix frontend":
      ensure  => "present",
      path    => "/etc/httpd/conf.d/zabbix.conf",
      source  => 'puppet:///modules/zabbix/zabbix_php', 
      require => Package[$_packages_to_install], 
      before  => Service['httpd'],
   }

   file { 'zabbix_php config':
      ensure  => "present",
      path    => "/etc/zabbix/web/zabbix.conf.php",
      content => epp('zabbix/zabbix_server.php.epp', { "password" => $::zabbix::mysql_password, "server_ip" => 'localhost'}),
      require => Package[$_packages_to_install],
      owner   => "apache",
      group   => "apache",
   }

   exec { 'fix_selinux_zabbix':
       subscribe   => Package['zabbix-server-mysql'],
       command     => "cd /var/tmp; /usr/sbin/ausearch -c 'zabbix_server' --raw | /usr/bin/audit2allow -M my-zabbixserver && /usr/sbin/semodule -i my-zabbixserver.pp; /usr/sbin/ausearch -c 'httpd' --raw | /usr/bin/audit2allow -M my-httpd && /usr/sbin/semodule -X 500 -i my-httpd.pp",
       refreshonly => true,
       require     => [ File['zabbix_php config'], File['zabbix config'], Service['mariadb']],
       before      => Service['zabbix-server'],
   }

   service { 'zabbix-server':
      ensure  => "running",
      enable  => true,
      require => [ File['zabbix_php config'], File['zabbix config'], Service['mariadb'] ],
   }
   
   service { 'mariadb':
      ensure  => "running",
      enable  => true,
      require => [Package[$_packages_to_install], Augeas['mariadb-disable-strict-mode']],
   }
  
   $::zabbix::templates.each |String $name, Hash $params| {
      zabbix::objects::template { $name:
         attributes => $params - ['items', 'triggers'],
         items      => $params['items'],
         triggers   => $params['triggers'],
         url        => "http://${::zabbix::server_ip}/zabbix",
         apiKey     => $::zabbix::api_key,
      }
   }

   $::zabbix::auto_registry.each |String $name, Hash $params| {
      zabbix::objects::auto_registry { $name:
         templates => $params['templates'],
         params    => $params - ['templates'],
         url       => "http://${::zabbix::server_ip}/zabbix",
         apiKey    => $::zabbix::api_key,
      }
   }
   
   if $::zabbix::daily_report == true {
      include zabbix::daily_report
   }

   class { 'apache':
       mpm_module    => 'prefork',
       default_vhost => false,
   }

   class { 'apache::mod::php':
      php_version => '7',
   }

   if $::zabbix::letsencrypt == true {
      class {'letsencrypt':
         email  => $::zabbix::email_to,
#         config => {
#            server => 'https://acme-staging-v02.api.letsencrypt.org/directory',
#         },
      }

      letsencrypt::certonly { $facts['fqdn']:
         plugin               => 'webroot',
         webroot_paths        => ['/var/www/html'],
         domains              => [$facts['fqdn']],
         manage_cron          => true,
         cron_success_command => '/bin/systemctl reload httpd',
      }

      if $::letsencrypt_directory[$facts['fqdn']] != undef {
         apache::vhost {"${facts['fqdn']}-ssl":
            servername      => $facts['fqdn'],
            ssl             => true,
            port            => '443',
            suphp_engine    => 'off',
            ssl_cert        => "${::letsencrypt_directory[$facts['fqdn']]}/cert.pem",
            ssl_key         => "${::letsencrypt_directory[$facts['fqdn']]}/privkey.pem",
            ssl_chain       => "${::letsencrypt_directory[$facts['fqdn']]}/fullchain.pem",
            docroot         => '/var/www/html',
            serveradmin     => $::zabbix::email_to,
            rewrites => [
                 {
                    rewrite_rule => ['^/$ /zabbix [PT]'],
                 },
                 {
                    rewrite_rule => ['^index\.html$ /zabbix [PT]'],
                 },
            ],
         }
         apache::vhost {$facts['fqdn']:
            servername      => $facts['fqdn'],
            ssl             => false,
            port            => '80',
            suphp_engine    => 'off',
            docroot         => '/var/www/html',
            serveradmin     => $::zabbix::email_to,
            redirect_status => 'permanent',
            redirect_dest   => "https://${facts['fqdn']}/",
         }
      } else {
         apache::vhost {$facts['fqdn']:
            servername      => $facts['fqdn'],
            ssl             => false,
            port            => '80',
            suphp_engine    => 'off',
            docroot         => '/var/www/html',
            serveradmin     => $::zabbix::email_to,
         }
      }
   } else {
      apache::vhost {$facts['fqdn']:
        servername      => $facts['fqdn'],
        ssl             => false,
        port            => '80',
        suphp_engine    => 'off',
        docroot         => '/var/www/html',
        serveradmin     => $::zabbix::email_to,
        rewrites => [
                 {
                    rewrite_rule => ['^/$ /zabbix [PT]'],
                 },
                 {
                    rewrite_rule => ['^index\.html$ /zabbix [PT]'],
                 },
        ], 
     }
   }
}
