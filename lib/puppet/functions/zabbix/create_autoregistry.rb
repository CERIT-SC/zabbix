require 'rest-client'
require 'json'

Puppet::Functions.create_function(:'zabbix::create_autoregistry') do

      $generic_payload = { "jsonrpc" => "2.0", "id" => 1}
      $url_g = ""

      dispatch :create_autoregistry do
         param 'Array',  :templates
         param 'Hash',   :params,
         param 'String', :url
         param 'String', :apiKey
      end


      def create_autoregistry(templates, params, url, apiKey)
         url += "/api_jsonrpc.php"
         $url_g = url
         $generic_payload = $generic_payload.merge({"auth" => apiKey})

         ids = getIdOfTemplates(templates)
         attributes = { "method" => "action.create", "params" => params }
         attributes['params']['operations'].push({ "operationtype" => 6, "optemplate" => ids })
         genericHttpPost(attributes)
      end


      def getIdOfTemplates(templates)
         arguments = { "method" => "template.get", "params" => {"filter" => { "host" => template }}}
         result = genericHttpGet(arguments)
         result.map { |template| { "templateid" => "#{template['templateid']}"} }
         return result
      end


      def genericHttpGet(payload)
         payload = payload.merge($generic_payload)
         begin
            result = RestClient::Request.execute(:url => $url_g, :method => "GET", :verify_ssl => false, :timeout => 10, :payload => payload.to_json, :headers => { "Content-Type" => "application/json"})
         rescue
            return []
         end
         return JSON.parse(result)['result']
      end


      def genericHttpPost(payload)
         payload = payload.merge($generic_payload)
         begin
            result = RestClient::Request.execute(:url => $url_g, :method => "POST", :verify_ssl => false, :timeout => 10, :payload => payload.to_json, :headers => { "Content-Type" => "application/json"})
         rescue
            return
         end
      end
end
