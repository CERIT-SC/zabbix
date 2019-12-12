require 'rest-client'
require 'json'

Puppet::Functions.create_function(:'zabbix::create_template') do

      $generic_payload = { "jsonrpc" => "2.0", "id" => 1 }
      $url_g = ""
      $template_id = ""

      dispatch :create_template do
         param 'Hash',   :attributes
         param 'Array',  :items
         param 'String', :url
         param 'String', :apiKey
      end

      def create_template(attributes, items, url, apiKey)
         url += "/api_jsonrpc.php"
         $url_g = url
         $generic_payload = $generic_payload.merge({"auth" => apiKey})

         attributes = { "method" => "template.create", "params" => attributes }
         genericHttpPost(attributes)
         createItems(items)
      end

      def createItems(items)
         items.each do |item|
             attributes = { "method" => "item.create", "params" => item }
             attributes = attributes.merge({ "params" => { "hostid" => $template_id }})
             genericHttpPost(attributes)
         end
      end

      def genericHttpPost(payload)
         payload = payload.merge($generic_payload)
         begin
            result = RestClient::Request.execute(:url => $url_g, :method => "POST", :verify_ssl => false, :timeout => 10, :payload => payload.to_json, :headers => { "Content-Type" => "application/json"})
         rescue
            return
         end
            if $template_id == "" 
              $template_id = JSON.parse(result)['result']['templateids'][0]
            end
      end

