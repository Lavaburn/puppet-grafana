require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_datasource).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Datasource"

  mk_resource_methods
  
  def flush      
    if @property_flush[:ensure] == :present
      create_datasource
      return
    end
          
    if @property_flush[:ensure] == :absent
      delete_datasource
      return
    end 
   
    update_datasource
  end  

  def self.instances
    result = []
    
    orgs = get_objects('orgs')
    unless orgs.nil?
      orgs.each do |org|
        org_id = org["id"].to_s
        #Puppet.debug "DS_PREFETCH - ORG = "+org_id
        
        http_post("user/using/#{org_id}")
        
        list = get_objects('datasources')     
        next if list.nil?
                
        list.each do |object|
          map = datasource_from_map(object)
          unless map.nil?
            #Puppet.debug "Datasource FOUND: "+map.inspect
            result.push(new(map))
          end  
        end        
      end
    end
    
    result 
  end

  def self.datasource_from_map(object)       
    return if object["name"].nil? 
      
    organisation = generic_lookup('orgs', 'id', object["orgId"], 'name')
      
    {
      :name               => object["name"]+"_"+organisation,
      :datasource_name    => object["name"],
      :type               => object["type"],   
      :access             => object["access"],   
      :url                => object["url"],   
      :user               => object["user"],   
      :password           => object["password"],   
      :database           => object["database"],   
      :basicauth          => object["basicAuth"],   
      :basicauth_user     => object["basicAuthUser"],   
      :basicauth_password => object["basicAuthPassword"],
      :json_data          => object["jsonData"],
      :secure_json_data   => object["secureJsonFields"],
      :is_default         => object["isDefault"],   
      :organisation       => organisation,
      :id                 => object["id"],
      :orgId              => object["orgId"],
      :ensure             => :present
    }
  end
  
  # TYPE SPECIFIC 
  private
  
  def create_datasource
    Puppet.debug "Create Datasource " + resource[:name]

    org_id = self.class.generic_lookup('orgs', 'name', resource[:organisation], 'id').to_s      
    #Puppet.debug "Switch context: ORG = "+org_id
    self.class.http_post("user/using/#{org_id}")

    params = {         
      :name               => resource[:datasource_name], 
      :type               => resource[:type],  
      :access             => resource[:access],  
      :url                => resource[:url],  
      :user               => resource[:user],  
      :password           => resource[:password],  
      :database           => resource[:database],  
      :basicAuth          => resource[:basicauth],
      :basicAuthUser      => resource[:basicauth_user],
      :basicAuthPassword  => resource[:basicauth_password],
      :jsonData           => resource[:json_data],
      :secureJsonFields   => resource[:secure_json_data],
      :isDefault          => resource[:is_default],
    }
    
    #Puppet.debug "POST datasources PARAMS = "+params.inspect
    self.class.http_post_json("datasources", params)
  end

  def delete_datasource
    Puppet.debug "Delete Datasource "+resource[:name]

    org_id = self.class.generic_lookup('orgs', 'name', resource[:organisation], 'id').to_s
    #Puppet.debug "Switch context: ORG = "+org_id
    self.class.http_post("user/using/#{org_id}")
    
    #Puppet.debug "DELETE datasources/#{@property_hash[:id]}"
    self.class.http_delete("datasources/#{@property_hash[:id]}")  
  end
  
  def update_datasource
    Puppet.debug "Update Datasource " + resource[:name]
      
    org_id = self.class.generic_lookup('orgs', 'name', resource[:organisation], 'id').to_s
    #Puppet.debug "Switch context: ORG = "+org_id
    self.class.http_post("user/using/#{org_id}")
   
    # name is the ID in Puppet - Can't update that...
    params = {
      :id                 => @property_hash[:id],
      :orgId              => org_id,
      :name               => resource[:datasource_name], 
      :type               => resource[:type],  
      :access             => resource[:access],  
      :url                => resource[:url],  
      :user               => resource[:user],  
      :password           => resource[:password],  
      :database           => resource[:database],  
      :basicAuth          => resource[:basicauth],
      :basicAuthUser      => resource[:basicauth_user],
      :basicAuthPassword  => resource[:basicauth_password],
      :jsonData           => resource[:json_data],
      :secureJsonFields   => resource[:secure_json_data],
      :isDefault          => resource[:is_default],
    }

    #Puppet.debug "PUT datasources/#{@property_hash[:id]} PARAMS = "+params.inspect
    self.class.http_put_json("datasources/#{@property_hash[:id]}", params)
  end  
end