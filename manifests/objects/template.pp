define zabbix::objects::template (
  Array  $items = [],
  Hash   $attributes,
  String $url,
  String $apiKey,
) {
   zabbix::create_template(attributes, items, url, apiKey)
}
