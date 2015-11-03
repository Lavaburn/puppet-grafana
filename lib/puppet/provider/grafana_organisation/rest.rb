require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_organisation).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Organisation"
  
  mk_resource_methods

  def flush  
    if @property_flush[:ensure] == :present
      createOrganisation
      return
    end
          
    if @property_flush[:ensure] == :absent
      deleteOrganisation
      return
    end 
   
    updateOrganisation
  end  

  def self.instances
    result = Array.new

    # Option 1 - Current auth organisation (API Token)
#    list = Array.new 
#    list.push get_objects('org')    # Single Org only for now...
    
    # Option 2 - ALL organisations (requires admin auth)    
    list = get_objects('orgs')
    
    if list != nil      
      list.each do |object|
        map = getOrganisation(object)
        if map != nil
          #Puppet.debug "Organisation FOUND: "+map.inspect
          result.push(new(map))
        end
      end       
    end   
     
    result 
  end
    
  def self.getOrganisation(object)   
    if object["name"] != nil 
      {
        :name           => object["name"],   

        :id             => object["id"],
          
        :ensure         => :present
      }
    end
  end
  
  # TYPE SPECIFIC    
  private
  def createOrganisation
    #Puppet.debug "Create Organisation "+resource[:name]
    
    params = {         
      :name     => resource[:name],
    }
    
    Puppet.debug "POST orgs PARAMS = "+params.inspect
    response = self.class.http_post('orgs', params)
  end

  def deleteOrganisation
    Puppet.debug "Delete Organisation "+resource[:name]

    # Unsupported ! 
#    Puppet.debug "DELETE orgs/#{@property_hash[:id]}"
#    response = self.class.http_delete("orgs/#{@property_hash[:id]}")    
  end
  
  def updateOrganisation
    Puppet.debug "Update Organisation "+resource[:name]
    
    # Currently not supported as name is used as ID in Puppet
    # Could be used to set/change city, address1, address2
  end  
end