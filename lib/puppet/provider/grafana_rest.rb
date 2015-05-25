begin
  require 'rest-client' if Puppet.features.rest_client?
  require 'json' if Puppet.features.json?
  require 'yaml/store' # TODO  
rescue LoadError => e
  Puppet.info "Grafana Puppet module requires 'rest-client' and 'json' ruby gems."
end

class Puppet::Provider::Rest < Puppet::Provider
  desc "Grafana API REST calls"
  
  confine :feature => :json
  confine :feature => :rest_client
  
  def initialize(value={})
    super(value)
    @property_flush = {} 
  end
    
  def self.get_rest_info
    config_file = "/etc/puppet/grafana_api.yaml"
    
    data = File.read(config_file) or raise "Could not read setting file #{config_file}"    
    yamldata = YAML.load(data)
        
    if yamldata.include?('ip')
      ip = yamldata['ip']
    else
      ip = '127.0.0.1'
    end

    if yamldata.include?('port')
      port = yamldata['port']
    else
      port = '3000'
    end
    
    result = { :ip => ip, :port => port }
    
    if yamldata.include?('user') and yamldata.include?('password')
      result[:user] = yamldata['user']
      result[:password] = yamldata['password']
    elsif yamldata.include?('api_key')
      result[:api_key] = yamldata['api_key']
    else      
      raise "The configuration file #{config_file} should include either user/password or api_key!"
    end
    
    if yamldata.include?('dashboards_folder')
      result[:dashboards_folder] = yamldata['dashboards_folder']
    else
      result[:dashboards_folder] = '/tmp/grafana-dashboards'
    end
    
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
      if resource = resources[prov.name]
       resource.provider = prov
      end
    end
  end  
   
  def self.get_objects(url, resultName = nil)    
    #Puppet.debug "GRAFANA-API (generic) get_objects: #{url}"
    
    response = http_get(url)
      
    #Puppet.debug("Call to #{url} on Grafana API returned #{response}")

    if resultName == nil
      response      
    else 
      response[resultName]      
    end
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
  
  def self.http_patch(url, data = {}) 
    http_generic('PATCH', url, data)
  end
  
  def self.http_delete(url) 
    http_generic('DELETE', url)
  end
  
  def self.http_generic(method, url, data = {}, sendJSON = false) 
    #Puppet.debug "GRAFANA-API HTTP #{method}: #{url}"
    
    rest = get_rest_info
    baseUrl = "http://#{rest[:ip]}:#{rest[:port]}/api/#{url}"
    headers = login
    if sendJSON
      headers[:content_type] = :json
      headers[:accept] = :json
    end
    
    response = getJSON(method, baseUrl, headers, data)
    
    #Puppet.debug "GRAFANA API - #{method} on #{url} returned: #{response}"
    
    response    
  end
  
  def self.getJSON(method, url, headers = {}, data = {})    
    #Puppet.debug "GRAFANA-API (getJSON) #{method}: #{url}"
    
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
      responseJson = JSON.parse(response)
    rescue
      raise "Could not parse the JSON response from GRAFANA API: #{response}"
    end
    
    responseJson
  end

  def self.login
    rest = get_rest_info
    
    if rest[:user] != nil
      # Admin Login - Session Cookie
      
      baseUrl = "http://#{rest[:ip]}:#{rest[:port]}"
      
      cookies = read_cookie
                
      # Ping (test if logged in)
      cookieHeader = {:cookies => cookies}
      RestClient.get("#{baseUrl}/api/login/ping", cookieHeader) { |response, request, result, block|
        case response.code
        when 200
          #Puppet.debug "Login cookie is still valid"
                    
          # COOKIE STILL VALID          
          grafana_user = cookies[:grafana_user]
          grafana_sess = cookies[:grafana_sess]
          grafana_remember = cookies[:grafana_remember]
            
          return {:cookies => {:grafana_user => grafana_user, :grafana_sess => grafana_sess, :grafana_remember => grafana_remember}} 
        when 401
          # Need to login !!
        else
          raise "Unexpected response on API Login PING:"
        end
      }

      # Login
      RestClient.post("#{baseUrl}/login", {"user" => rest[:user], "password" => rest[:password]}) { |response, request, result, block|
        case response.code
        when 200
          #Puppet.debug "Login done. Using new cookie data. #{response.cookies.inspect}"
          
          # LOGIN OK
          grafana_user = response.cookies["grafana_user"]
          grafana_sess = response.cookies["grafana_sess"]
          grafana_remember = response.cookies["grafana_remember"]
            
          write_cookie(grafana_user, grafana_sess, grafana_remember)
                                 
          return {:cookies => {:grafana_user => grafana_user, :grafana_sess => grafana_sess, :grafana_remember => grafana_remember}} 
        when 401
          raise "Invalid Authentication in Grafana REST API Config File [TODO]"
        else
          raise "Unexpected response on API LOGIN:"
        end
      }              
    else 
      # API Token (Limits functionality severaly, as API Tokens are limited to 1 Organisation => BREAKS CODE RIGHT NOW !! (/orgs, /users endpoints don't exist with this type of AUTH (?) )
      return { :Authorization => "Bearer #{rest[:api_key]}" }
    end
    
    return {} 
  end    
  
  def self.read_cookie
    #Puppet.debug "Read cookie from file"
    
    file = "/tmp/grafana_cookie.yaml"
    
    if !File.exist?(file)
      return {}
    end
    
    data = File.read(file) or return {}
    yamldata = YAML.load(data)
 
    if yamldata.include?('grafana_user') and yamldata.include?('grafana_sess') and yamldata.include?('grafana_remember')  
      grafana_user = yamldata['grafana_user']
      grafana_sess = yamldata['grafana_sess']
      grafana_remember = yamldata['grafana_remember']
      return {:grafana_user => grafana_user, :grafana_sess => grafana_sess, :grafana_remember => grafana_remember}
    end
    
    return {}
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
  
  def self.genericLookup(endpoint, lookupVar, lookupVal, returnVar)
    list = get_objects(endpoint)
           
    if list != nil
      list.each do |object|
        if object[lookupVar] == lookupVal
          return object[returnVar]
        end        
      end
    end
  
    raise "Could not find "+endpoint+" where "+lookupVar+" = "+lookupVal
  end  
end