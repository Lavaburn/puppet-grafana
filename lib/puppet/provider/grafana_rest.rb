begin
  require 'rest-client' if Puppet.features.rest_client?
  require 'json' if Puppet.features.json?
  require 'yaml/store' # TODO  
rescue LoadError
  Puppet.info "Grafana Puppet module requires 'rest-client' and 'json' ruby gems."
end

class Puppet::Provider::Rest < Puppet::Provider
  desc "Grafana API REST calls"
  
  confine :feature => :json
  confine :feature => :rest_client
  
  def initialize(value = {})
    super(value)
    @property_flush = {} 
  end
    
  def self.rest_info
    config_file = "/etc/grafana/api.yaml"
    
    data = File.read(config_file) || raise("Could not read setting file #{config_file}")    
    yamldata = YAML.load(data)
        
    ip = yamldata.include?('ip') ? yamldata['ip'] : '127.0.0.1'
    port = yamldata.include?('port') ? yamldata['port'] : '3000'
    
    result = { :ip => ip, :port => port }
    
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
   
  def self.get_objects(url, resultName = nil)    
    #Puppet.debug "GRAFANA-API (generic) get_objects: #{url}"
    
    response = http_get(url)
      
    #Puppet.debug("Call to #{url} on Grafana API returned #{response}")
    
    return response if resultName.nil?   
    response[resultName]
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
    base_url = "http://#{rest[:ip]}:#{rest[:port]}/api/#{url}"
    headers = login
    if send_json
      headers[:content_type] = :json
      headers[:accept] = :json
    end
    
    response = http_json(method, base_url, headers, data)
    
    #Puppet.debug "GRAFANA API - #{method} on #{url} returned: #{response}"
    
    response    
  end
  
  def self.http_json(method, url, headers = {}, data = {})    
    #Puppet.debug "GRAFANA-API (http_json) #{method}: #{url}"
    
    begin
      case method
      when 'GET'
        response = RestClient.get url, headers         
      when 'POST'        
        response = RestClient.post url, data, headers        
      when 'PUT'
        response = RestClient.put url, data, headers
      when 'PATCH'
        response = RestClient.patch url, data, headers
      when 'DELETE'
        response = RestClient.delete url, headers         
      else
        raise "GRAFANA-API - Invalid Method: #{method}"
      end
    rescue => e
      Puppet.debug "GRAFANA API response: "+e.inspect
      raise "Unable to contact GRAFANA API on #{url}: #{e.response}"
    end
  
    begin
      response_json = JSON.parse(response)
    rescue
      raise "Could not parse the JSON response from GRAFANA API: #{response}"
    end
    
    response_json
  end

  def self.login
    rest = rest_info

    # API Token (Limits functionality severaly, as API Tokens are limited to 1 Organisation => BREAKS CODE RIGHT NOW !! (/orgs, /users endpoints don't exist with this type of AUTH (?) )
    return { :Authorization => "Bearer #{rest[:api_key]}" } if rest[:user].nil?
    
    # Admin Login - Session Cookie      
    base_url = "http://#{rest[:ip]}:#{rest[:port]}"
    
    cookies = read_cookie
              
    # Ping (test if logged in)
    cookie_header = { :cookies => cookies }
    RestClient.get("#{base_url}/api/login/ping", cookie_header) do |response, _request, _result, _block|
      case response.code
      when 200
        #Puppet.debug "Login cookie is still valid"
                  
        # COOKIE STILL VALID          
        grafana_user = cookies[:grafana_user]
        grafana_sess = cookies[:grafana_sess]
        grafana_remember = cookies[:grafana_remember]
          
        return { :cookies => { 
          :grafana_user => grafana_user, 
          :grafana_sess => grafana_sess, 
          :grafana_remember => grafana_remember 
        } } 
      else
        raise "Unexpected response on API Login PING:" unless response.code == 401
      end
    end

    # Login
    RestClient.post("#{base_url}/login", { "user" => rest[:user], "password" => rest[:password] }) do |response, _request, _result, _block|
      case response.code
      when 200
        #Puppet.debug "Login done. Using new cookie data. #{response.cookies.inspect}"
        
        # LOGIN OK
        grafana_user = response.cookies["grafana_user"]
        grafana_sess = response.cookies["grafana_sess"]
        grafana_remember = response.cookies["grafana_remember"]
          
        write_cookie(grafana_user, grafana_sess, grafana_remember)
                               
        return { :cookies => {
          :grafana_user => grafana_user, 
          :grafana_sess => grafana_sess, 
          :grafana_remember => grafana_remember
        } } 
      when 401
        raise "Invalid Authentication in Grafana REST API Config File [TODO]"
      else
        raise "Unexpected response on API LOGIN:"
      end
    end
    
    {} 
  end    
  
  def self.read_cookie
    #Puppet.debug "Read cookie from file"
    
    file = "/tmp/grafana_cookie.yaml"    
    return {} unless File.exist?(file)    
    return {} unless (data = File.read(file)) 
    yamldata = YAML.load(data)
 
    if yamldata.include?('grafana_user') && yamldata.include?('grafana_sess') && yamldata.include?('grafana_remember')  
      grafana_user = yamldata['grafana_user']
      grafana_sess = yamldata['grafana_sess']
      grafana_remember = yamldata['grafana_remember']
      return { :grafana_user => grafana_user, :grafana_sess => grafana_sess, :grafana_remember => grafana_remember }
    end
    
    {}
  end
  
  def self.write_cookie(grafana_user, grafana_sess, grafana_remember)
    #Puppet.debug "Write cookie to file"
    
    file = "/tmp/grafana_cookie.yaml"
    
    cookie = YAML::Store.new(file)
  
    cookie.transaction do
      cookie["grafana_user"] = grafana_user
      cookie["grafana_sess"] = grafana_sess
      cookie["grafana_remember"] = grafana_remember
    end
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