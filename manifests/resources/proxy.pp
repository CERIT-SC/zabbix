# == Class zabbix::resources::proxy
#
# This will create an resources into puppetdb
# for automatically configuring proxy agent into
# zabbix front-end.
#
# === Requirements
#
# Nothing.
#
# When manage_resource is set to true, this class
# will be loaded from 'zabbix::proxy'. So no need
# for loading this class manually.

class zabbix::resources::proxy (
  $hostname  = undef,
  $ipaddress = undef,
  $use_ip    = undef,
  $mode      = undef,
  $port      = undef,
) {

  @@zabbix_proxy { $hostname:
    proxy_address => $ipaddress,
    mode          => $mode,
  }
}
