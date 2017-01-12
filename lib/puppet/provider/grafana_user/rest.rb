require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_user).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana User"
  
  mk_resource_methods

  def flush     
    if @property_flush[:ensure] == :present
      createUser
      return
    end
          
    if @property_flush[:ensure] == :absent
      deleteUser
      return
    end 
   
    updateUser
  end  

  def self.instances
    result = Array.new
    
    # Option 1 - Current auth organisation (API Token)
    #list = get_objects('org/users')
        
    # Option 2 - ALL organisations (requires admin auth)    
    list = get_objects('users')    
    
    if list != nil      
      list.each do |object|
        map = getUser(object)
        if map != nil
          #Puppet.debug "User FOUND: "+map.inspect
          result.push(new(map))
        end
      end       
    end   
     
    result
  end
  
  def self.getObject(id)
    list = get_objects('users')    
    if list != nil      
      list.each do |object|        
        if object["id"] == id
          return getUser(object)
        end
      end
    end
    
    raise "Could not retrieve user "+@property_hash[:id] 
  end
    
  def self.getUser(object)   
    if object["login"] != nil 
      organisations = Hash.new
      
      list = get_objects("users/#{object["id"]}/orgs") 
      if list != nil      
        list.each do |object|          
          organisation = genericLookup('orgs', 'id', object["orgId"], 'name')   
          organisations[organisation] = object["role"].downcase
        end       
      end
      organisations.sort_by { |name, role| name }
      
      {
        :name           => object["name"],  
        :email          => object["email"],    
        :login          => object["login"],   
        :is_admin       => object["isAdmin"],  
        :organisations  => organisations,
        
        :id             => object["id"],     
        
        :ensure         => :present
      }
    end
  end
  
  # TYPE SPECIFIC    
  private
  def createUser
    Puppet.debug "Create User "+resource[:name]
                
    params = {         
      :name     => resource[:name],
      :email    => resource[:email],
      :login    => resource[:login], 
      :password => resource[:password],
    }
    
    #Puppet.debug "POST org/users PARAMS = "+params.inspect
    response = self.class.http_post('admin/users', params)
    user_id = response["id"]
    
    # Link to Organisation
    resource[:organisations].each do |neworg, newrole|
      orgId = self.class.genericLookup('orgs', 'name', neworg, 'id').to_s
        
      #Puppet.debug "Switch context: ORG = "+orgId
      self.class.http_post("user/using/"+orgId)
                  
      params = { 
        :loginOrEmail => resource[:login],
        :role         => newrole.capitalize,
      }
          
      #Puppet.debug "POST orgs/#{orgId}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
      response = self.class.http_post_json("orgs/#{orgId}/users", params) 
    end
    
    # By default, the user will get viewer permissions on "Main Org."
    found = false
    
    resource[:organisations].each do |neworg, newrole|
      if neworg == "Main Org."
        found = true
      end
    end
    
    if ! found 
      # Remove permissions that do not exist
      orgId = self.class.genericLookup('orgs', 'name', "Main Org.", 'id').to_s  
      
      #Puppet.debug "DELETE orgs/#{orgId}/users/#{@property_hash[:id]}"
      response = self.class.http_delete("orgs/#{orgId}/users/#{user_id}") 
    end
  end

  def deleteUser
    #Puppet.debug "Delete User "+resource[:name]
      
    #Puppet.debug "DELETE admin/users/#{@property_hash[:id]}"
    response = self.class.http_delete("admin/users/#{@property_hash[:id]}")    
  end
  
  def updateUser
    Puppet.debug "Update User "+resource[:name]
      
    oldObject = self.class.getObject(@property_hash[:id])
          
    if oldObject[:login] != resource[:login] or oldObject[:email] != resource[:email]
      params = {    # name is the ID in Puppet - Can't update that...
        :login          => resource[:login], 
        :email          => resource[:email],
      }
  
      #Puppet.debug "PUT users/#{@property_hash[:id]} PARAMS = "+params.inspect
      response = self.class.http_put("users/#{@property_hash[:id]}", params)  
    end  
    
    if oldObject[:is_admin] != resource[:is_admin]
      params = {
        :isGrafanaAdmin => resource[:is_admin],
      }
  
      Puppet.debug "PUT admin/users/#{@property_hash[:id]}/permissions PARAMS = "+params.inspect
      response = self.class.http_put("admin/users/#{@property_hash[:id]}/permissions", params)
    end       
      
    if oldObject[:organisations] != resource[:organisations]
      Puppet.debug "Update organisations for user "+resource[:name]
        
      #Delete or update
      oldObject[:organisations].each do |org, role|
        found_role = nil
        resource[:organisations].each do |neworg, newrole|
          if neworg == org
            found_role = newrole
          end
        end
        
        if found_role == nil
          orgId = self.class.genericLookup('orgs', 'name', org, 'id').to_s      
          
          #Puppet.debug "DELETE orgs/#{orgId}/users/#{@property_hash[:id]}"
          response = self.class.http_delete("orgs/#{orgId}/users/#{@property_hash[:id]}") 
        else  
          if found_role != role
            orgId = self.class.genericLookup('orgs', 'name', org, 'id').to_s
            params = { 
              :orgId  => orgId, 
              :userId => @property_hash[:id], 
              :email  => @property_hash[:email], 
              :login  => @property_hash[:login], 
              :role   => found_role.capitalize,
            }
              
            #Puppet.debug "PATCH orgs/#{orgId}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
            response = self.class.http_patch("orgs/#{orgId}/users/#{@property_hash[:id]}", params) 
          end
        end
      end
       
      # Create
      resource[:organisations].each do |neworg, newrole|
        found = false
        oldObject[:organisations].each do |org, role|
          if neworg == org
            found = true
          end
        end
        if !found
          orgId = self.class.genericLookup('orgs', 'name', neworg, 'id').to_s
          
          #Puppet.debug "Switch context: ORG = "+orgId
          self.class.http_post("user/using/"+orgId)
                    
          params = { 
            :loginOrEmail => @property_hash[:login], 
            :role => newrole.capitalize,
          }
            
          #Puppet.debug "POST orgs/#{orgId}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
          response = self.class.http_post_json("orgs/#{orgId}/users", params) 
        end
      end
    end
  end  
end