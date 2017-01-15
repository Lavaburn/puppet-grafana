require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_organisation).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Organisation"
  
  confine :feature => :json
  confine :feature => :rest_client
  confine :feature => :api_config
  
  mk_resource_methods

  def flush  
    if @property_flush[:ensure] == :present
      create_organisation
      return
    end
          
    if @property_flush[:ensure] == :absent
      delete_organisation
      return
    end 
   
    update_organisation
  end  

  def self.instances
    result = []

    # Option 1 - Current auth organisation (API Token)
#    list = Array.new 
#    list.push get_objects('org')    # Single Org only for now...
    
    # Option 2 - ALL organisations (requires admin auth)    
    list = get_objects('orgs')
    
    unless list.nil?
      list.each do |object|
        map = organisation_from_map(object)
        unless map.nil?
          #Puppet.debug "Organisation FOUND: "+map.inspect
          result.push(new(map))
        end
      end       
    end   
     
    result 
  end
    
  def self.organisation_from_map(object)   
    return if object["name"].nil? 
    
    {
      :name   => object["name"],   
      :id     => object["id"],          
      :ensure => :present
    }
  end
  
  # TYPE SPECIFIC    
  private
  
  def create_organisation
    #Puppet.debug "Create Organisation "+resource[:name]
    
    params = {         
      :name => resource[:name],
    }
    
    Puppet.debug "POST orgs PARAMS = " + params.inspect
    self.class.http_post('orgs', params)
  end

  def delete_organisation
    Puppet.debug "Delete Organisation " + resource[:name]

    # Unsupported ! 
#    Puppet.debug "DELETE orgs/#{@property_hash[:id]}"
#    response = self.class.http_delete("orgs/#{@property_hash[:id]}")    
  end
  
  def update_organisation
    Puppet.debug "Update Organisation " + resource[:name]
    
    # Currently not supported as name is used as ID in Puppet
    # Could be used to set/change city, address1, address2
  end  
end