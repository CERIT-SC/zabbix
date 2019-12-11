class zabbix::role::server {

   case $facts['operatingsystem'] {
       'CentOS': {
            if $facts['operatingsystemmajrelease'] == "7" {

                package {'zabbix':
                    provider => 'rpm',
                    ensure   => "installed",
                    source   => 'https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm',
                }

            } else {
               fail("This version of CentOS is unsupported")   
            }
        }
        default: {
            fail("This OS is unsupported")
       }
   }

   $packages_to_install = ["zabbix-server-mysql", "zabbix-web-mysql", "zabbix-agent", "mariadb-server"]

   package { $packages_to_install:
       ensure  => "installed",
       require => Package['zabbix'],
   }
   
   exec { 'create zabbix db':
       subscribte  => Package[$packages_to_install],
       command     => '/bin/mysql -uroot -e "create database zabbix character set utf8 collate utf8_bin;"',
       refreshonly => true,
       require     => Package[$packages_to_install],
   }

   exec { 'grant privileges on zabbix':
       subscribte  => Exec['create zabbix db'],
       command     => "/bin/mysql -uroot -e \"grant all privileges on zabbix.* to zabbix@localhost identified by \'${::zabbix::mysql_password}\'\";",
       refreshonly => true,
       require     => Exec['create zabbix db'],
   }

   exec { 'import initial schema':
       subscribte  => Exec[grant privileges on zabbix],
       command     => "/bin/zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | /bin/mysql -uzabbix -p${::zabbix::mysql_password}",
       refreshonly => true,
       require     => Exec['grant privileges on zabbix'],
   }


   file { 'zabbix config':
      ensure  => "present",
      path    => "/etc/zabbix/zabbix_server.conf",
      content => epp('/zabbix/zabbix_server.conf.epp', { "password" => $::zabbix::mysql_password }),
      require => Package[$packages_to_install],
   }
  
   file { "zabbix frontend":
      ensure  => "present",
      path    => "/etc/httpd/conf.d/zabbix.conf",
      source  => 'puppet:///modules/zabbix/zabbix_php", 
      require => Package[$packages_to_install], 
   }

   file { 'zabbix_php config':
      ensure  => "present",
      path    => "/etc/zabbix/web/zabbix.conf.php",
      content => epp('zabbix/zabbix_server.php.epp', { "password" => $::zabbix::mysql_password }),
      require => Package[$packages_to_install],
   }

   service { 'zabbix-server':
      ensure  => "running",
      enable  => true,
      require => [ File['zabbix_php config'], File['zabbix config'] ],
   }
   
   service { 'httpd':
      ensure  => "running",
      enable  => true,
      require => File['zabbix frontend'],
   }
}
