define zabbix::objects::auto_registry (
  Array[String]  $templates,
  String         $url,
  Hash           $params,
  String         $apiKey,
) {
    zabbix::create_autoregistry($templates, $params, $url, $apiKey)
}
