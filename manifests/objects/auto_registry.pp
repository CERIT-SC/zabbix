define zabbix::objects::auto_registry (
  Array[String]  $templates,
  String         $url,
  String         $apiKey,
) {
    zabbix::create_autoregistry($templates, $url, $apiKey)
}
