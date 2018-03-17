begin
  require 'rest-client' if Puppet.features.rest_client?
  require 'json' if Puppet.features.json?
  require 'yaml/store' # TODO  
rescue LoadError
  Puppet.info "Grafana Puppet module requires 'rest-client' and 'json' ruby gems."
end

class Puppet::Provider::Rest < Puppet::Provider
  desc "Grafana API REST calls"
  
  def initialize(value = {})
    super(value)
    @property_flush = {} 
  end
    
  def self.rest_info
    config_file = "/etc/grafana/api.yaml"
    
    raise("Could not read setting file #{config_file}") unless File.exist?(config_file)
    
    data = File.read(config_file)
    yamldata = YAML.safe_load(data)
        
    ip = yamldata.include?('ip') ? yamldata['ip'] : '127.0.0.1'
    port = yamldata.include?('port') ? yamldata['port'] : '3000'
    protocol = yamldata.include?('protocol') ? yamldata['protocol'] : 'http'
    insecure = yamldata.include?('insecure') ? yamldata['insecure'] : false
    
    result = { :protocol => protocol, :ip => ip, :port => port, :insecure => insecure }
    
    if yamldata.include?('user') && yamldata.include?('password')
      result[:user] = yamldata['user']
      result[:password] = yamldata['password']
    elsif yamldata.include?('api_key')
      result[:api_key] = yamldata['api_key']
    else      
      raise "The configuration file #{config_file} should include either user/password or api_key!"
    end
    
    result[:dashboards_folder] = yamldata.include?('dashboards_folder') ? yamldata['dashboards_folder'] : result[:dashboards_folder] = '/tmp/grafana-dashboards'
    
    result
  end

  def exists?    
    @property_hash[:ensure] == :present
  end
  
  def create
    @property_flush[:ensure] = :present
  end

  def destroy        
    @property_flush[:ensure] = :absent
  end
          
  def self.prefetch(resources)        
    instances.each do |prov|
      if (resource = resources[prov.name])
       resource.provider = prov
      end
    end
  end  
   
  def self.get_objects(url, result_name = nil)
    #Puppet.debug "GRAFANA-API (generic) get_objects: #{url}"
    
    response = http_get(url)
      
    #Puppet.debug("Call to #{url} on Grafana API returned #{response}")
    
    return response if result_name.nil?   
    response[result_name]
  end
  
  def self.http_get(url) 
    http_generic('GET', url)
  end

  def self.http_post(url, data = {}) 
    http_generic('POST', url, data)
  end
  
  def self.http_post_json(url, data = {}) 
    http_generic('POST', url, data.to_json, true)
  end
  
  def self.http_put(url, data = {}) 
    http_generic('PUT', url, data)
  end

  def self.http_put_json(url, data = {}) 
    http_generic('PUT', url, data.to_json, true)
  end

  def self.http_patch(url, data = {}) 
    http_generic('PATCH', url, data)
  end
  
  def self.http_delete(url) 
    http_generic('DELETE', url)
  end
  
  def self.http_generic(method, url, data = {}, send_json = false) 
    #Puppet.debug "GRAFANA-API HTTP #{method}: #{url}"
    
    rest = rest_info
        
    base_url = "#{rest[:protocol]}://#{rest[:ip]}:#{rest[:port]}/api/#{url}"
    headers = login
    if send_json
      headers[:content_type] = :json
      headers[:accept] = :json
    end
    
    response = http_json(method, base_url, headers, data, rest[:insecure])
    
    #Puppet.debug "GRAFANA API - #{method} on #{url} returned: #{response}"
    
    response    
  end
  
  def self.http_json(method, url, headers = {}, data = {}, insecure = false)    
    # Puppet.debug "GRAFANA-API (http_json) #{method}: #{url}"

    verify_ssl = true
    verify_ssl = false if insecure
    
    begin
      case method
      when 'GET'
        response = RestClient::Request.execute(method: :get, url: url, headers: headers, verify_ssl: verify_ssl)
      when 'POST'   
        response = RestClient::Request.execute(method: :post, url: url, headers: headers, payload: data, verify_ssl: verify_ssl)
      when 'PUT'
        response = RestClient::Request.execute(method: :put, url: url, headers: headers, payload: data, verify_ssl: verify_ssl)
      when 'PATCH'
        response = RestClient::Request.execute(method: :patch, url: url, headers: headers, payload: data, verify_ssl: verify_ssl)
      when 'DELETE'
        response = RestClient::Request.execute(method: :delete, url: url, headers: headers, verify_ssl: verify_ssl)
      else
        raise "GRAFANA-API - Invalid Method: #{method}"
      end
    rescue RestClient::RequestFailed => e
      Puppet.debug "GRAFANA API response: "+e.inspect
      raise "Unable to contact GRAFANA API on #{url}: #{e.response}"
    end
  
    begin
      response_json = JSON.parse(response)
    rescue JSON::ParserError
      raise "Could not parse the JSON response from GRAFANA API: #{response}"
    end
    
    response_json
  end

  def self.login
    rest = rest_info

    verify_ssl = true
    verify_ssl = false if rest[:insecure]
    
    # API Token (Limits functionality severily, as API Tokens are limited to 1 Organisation => BREAKS CODE RIGHT NOW !! (/orgs, /users endpoints don't exist with this type of AUTH (?) )
    return { :Authorization => "Bearer #{rest[:api_key]}" } if rest[:user].nil?
    
    # Admin Login - Session Cookie      
    base_url = "#{rest[:protocol]}://#{rest[:ip]}:#{rest[:port]}"
    
    cookie_jar = load_cookies
              
    # Ping (test if logged in)
    cookie_header = { :cookies => cookie_jar }

    RestClient::Request.execute(method: :get, url: "#{base_url}/api/login/ping", headers: cookie_header, verify_ssl: verify_ssl) do |response, _request, _result, _block|
      case response.code
      when 200
        # Puppet.debug "Login cookie is still valid"

        store_cookies(response.cookie_jar)          
        return { :cookies => response.cookie_jar }
      else
        raise "Unexpected response on API Login PING:" unless response.code == 401
      end
    end

    # Login
    data = { "user" => rest[:user], "password" => rest[:password] }
    RestClient::Request.execute(method: :post, url: "#{base_url}/login", payload: data, verify_ssl: verify_ssl) do |response, _request, _result, _block|
      case response.code
      when 200
        # Puppet.debug "Login done. Using new cookie data. #{response.cookies.inspect}"
        
        store_cookies(response.cookie_jar)                               
        return { :cookies => response.cookie_jar }
      when 401
        raise "Invalid Authentication in Grafana REST API Config File [TODO]"
      else
        raise "Unexpected response on API LOGIN:"
      end
    end
    
    {} 
  end

  def self.load_cookies
    # Puppet.debug "Read cookie from file"
    
    filename = "/tmp/grafana_cookiejar.txt"
    options = {}
    
    cookie_jar = HTTP::CookieJar.new
    cookie_jar.load(filename, options) if File.exist?(filename)
    cookie_jar
  end

  def self.store_cookies(cookie_jar)
    # Puppet.debug "Write cookie to file"
    
    file = "/tmp/grafana_cookiejar.txt"
    options = {
      :session => true,
    }
    
    cookie_jar.save(file, options)
  end
  
  def self.generic_lookup(endpoint, lookup_var, lookup_val, return_var)
    list = get_objects(endpoint)
           
    unless list.nil?
      list.each do |object|
        return object[return_var] if object[lookup_var] == lookup_val
      end
    end
  
    raise "Could not find "+endpoint+" where "+lookup_var+" = "+lookup_val
  end  
end