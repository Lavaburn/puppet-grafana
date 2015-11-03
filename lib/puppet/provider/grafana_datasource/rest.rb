require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_datasource).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Datasource"

  mk_resource_methods
  
  def flush      
    if @property_flush[:ensure] == :present
      createDatasource
      return
    end
          
    if @property_flush[:ensure] == :absent
      deleteDatasource
      return
    end 
   
    updateDatasource
  end  

  def self.instances
    result = Array.new
    
    orgs = get_objects('orgs')
    if orgs != nil
      orgs.each do |org|
        orgId = org["id"].to_s
        #Puppet.debug "DS_PREFETCH - ORG = "+orgId
        
        http_post("user/using/"+orgId)
        
        list = get_objects('datasources')           
        if list != nil      
          list.each do |object|
            map = getDatasource(object)
            if map != nil
              #Puppet.debug "Datasource FOUND: "+map.inspect
              result.push(new(map))
            end  
          end
        end
        
      end
    end
    
    result 
  end

  def self.getDatasource(object)       
    if object["name"] != nil    
      organisation = genericLookup('orgs', 'id', object["orgId"], 'name')
        
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
        :is_default         => object["isDefault"],   
        :organisation       => organisation,

        :id                 => object["id"],
        :orgId              => object["orgId"],
        :json_data          => object["jsonData"],

        :ensure             => :present
      }
    end
  end
  
  # TYPE SPECIFIC 
  private
  def createDatasource
    Puppet.debug "Create Datasource "+resource[:name]

    orgId = self.class.genericLookup('orgs', 'name', resource[:organisation], 'id').to_s      
    #Puppet.debug "Switch context: ORG = "+orgId
    self.class.http_post("user/using/"+orgId)
                
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
      :isDefault          => resource[:is_default],   # TODO TEST (does not work => no errors given) !!!
    }
    
    #Puppet.debug "PUT datasources PARAMS = "+params.inspect
    response = self.class.http_put('datasources', params)
  end

  def deleteDatasource
    Puppet.debug "Delete Datasource "+resource[:name]

    orgId = self.class.genericLookup('orgs', 'name', resource[:organisation], 'id').to_s
    #Puppet.debug "Switch context: ORG = "+orgId
    self.class.http_post("user/using/"+orgId)
    
    Puppet.debug "DELETE datasources/#{@property_hash[:id]}"
    response = self.class.http_delete("datasources/#{@property_hash[:id]}")  
  end
  
  def updateDatasource
    Puppet.debug "Update Datasource "+resource[:name]
      
    orgId = self.class.genericLookup('orgs', 'name', resource[:organisation], 'id').to_s
    #Puppet.debug "Switch context: ORG = "+orgId
    self.class.http_post("user/using/"+orgId)

    params = {    # name is the ID in Puppet - Can't update that...
      :id                 => @property_hash[:id],
      :orgId              => orgId,
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
      :isDefault          => resource[:is_default],           # TODO TEST (does not work => no errors given) !!!
    }

    Puppet.debug "POST datasources PARAMS = "+params.inspect
    response = self.class.http_post("datasources", params)
  end  
end