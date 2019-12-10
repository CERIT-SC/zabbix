class zabbix::role::server {

   case $facts['operatingsystem'] {
       'CentOS': {
            if $facts['operatingsystemmajrelease'] == "7" {

                package {'zabbix':
                    provider => 'rpm',
                    ensure   => installed,
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
   
   file { 'mysql_credentials':
       path    => "~/.my.cnf",
       ensure  => "present",
       content => epp(), #TODO
       require => Package[$packages_to_install],
   }

   exec { 'create zabbix db':
       subscribte  => Package[$packages_to_install],
       command     => 'mysql -e "create database zabbix character set utf8 collate utf8_bin;"',
       refreshonly => true,
       require     => File['mysql_credentials'],
   }

   exec { 'grant privileges on zabbix':
       subscribte  => Package[$packages_to_install],
       command     => "mysql -e \"grant all privileges on zabbix.* to zabbix@localhost identified by \'${::zabbix::mysql_password}\'\";",
       refreshonly => true,
       require     => [ File['mysql_credentials'], Exec['create zabbix db'] ],
   }

   exec { 'import initial schema':
       subscribte  => Package[$packages_to_install],
       command     => "zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -u${::zabbix::mysql_username} -p${::zabbix::mysql_password}",
       refreshonly => true,
       require     => Exec['grant privileges on zabbix'],
   }


   file { 'zabbix config':
      ensure  => "present",
      path    => "/etc/zabbix/zabbix_server.conf",
      content => epp(), #TODO
      require => Package[$packages_to_install],
   }
  
   #TODO EDIT HTTPD conf.d
   # START SERVICES
   # update web/zabbix_server.conf.php
}

