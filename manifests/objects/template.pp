define zabbix::objects::template (
  Array  $items    = [],
  Array  $triggers = [],
  Hash   $attributes,
  String $url,
  String $apiKey,
) {
   zabbix::create_template($attributes, $items, $triggers, $url, $apiKey)
}
