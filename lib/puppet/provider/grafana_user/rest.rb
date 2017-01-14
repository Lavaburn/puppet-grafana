require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_user).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana User"
  
  mk_resource_methods

  def flush     
    if @property_flush[:ensure] == :present
      create_user
      return
    end
          
    if @property_flush[:ensure] == :absent
      delete_user
      return
    end 
   
    update_user
  end  

  def self.instances
    result = []
    
    # Option 1 - Current auth organisation (API Token)
    #list = get_objects('org/users')
        
    # Option 2 - ALL organisations (requires admin auth)    
    list = get_objects('users')    
    
    unless list.nil?   
      list.each do |object|
        map = user_from_map(object)
        unless map.nil?
          #Puppet.debug "User FOUND: "+map.inspect
          result.push(new(map))
        end
      end       
    end   
     
    result
  end
  
  def self.user_object(id)
    list = get_objects('users')    
    unless list.nil?   
      list.each do |object|        
        return user_from_map(object) if object["id"] == id
      end
    end
    
    raise "Could not retrieve user " + @property_hash[:id] 
  end
    
  def self.user_from_map(object)     
    return if object["login"].nil?
      
    organisations = {}
    
    orgs = get_objects("users/#{object['id']}/orgs") 
    unless orgs.nil?
      orgs.each do |org|
        organisation = generic_lookup('orgs', 'id', org["orgId"], 'name')   
        organisations[organisation] = org["role"].downcase
      end       
    end
    
    organisations.sort_by { |name, _role| name }
    
    {
      :ensure        => :present,
      :id            => object["id"],     
      :name          => object["name"],  
      :email         => object["email"],    
      :login         => object["login"],   
      :is_admin      => object["isAdmin"],  
      :organisations => organisations
    }
  end
  
  # TYPE SPECIFIC    
  private
  
  def create_user
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
      
    # Set Admin (if required)
    if resource[:is_admin]
      params = {
        :isGrafanaAdmin => resource[:is_admin],
      }
  
      Puppet.debug "PUT admin/users/#{@property_hash[:id]}/permissions PARAMS = "+params.inspect
      response = self.class.http_put_json("admin/users/#{@property_hash[:id]}/permissions", params)
      Puppet.debug "PUT permissions RESULT: "+response.inspect
    end
    
    # Link to Organisation
    resource[:organisations].each do |neworg, newrole|
      org_id = self.class.generic_lookup('orgs', 'name', neworg, 'id').to_s        
      #Puppet.debug "Switch context: ORG = "+org_id
      self.class.http_post("user/using/#{org_id}")
                  
      params = { 
        :loginOrEmail => resource[:login],
        :role         => newrole.capitalize,
      }
          
      #Puppet.debug "POST orgs/#{org_id}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
      response = self.class.http_post_json("orgs/#{org_id}/users", params) 
    end
    
    # By default, the user will get viewer permissions on "Main Org."
    found = false
    
    resource[:organisations].each do |neworg, _newrole|
      found = true if neworg == "Main Org."
    end
    
    return if found
     
    # Remove permissions that do not exist
    org_id = self.class.generic_lookup('orgs', 'name', "Main Org.", 'id').to_s
    #Puppet.debug "DELETE orgs/#{org_id}/users/#{@property_hash[:id]}"
    self.class.http_delete("orgs/#{org_id}/users/#{user_id}")
  end

  def delete_user
    #Puppet.debug "Delete User "+resource[:name]
      
    #Puppet.debug "DELETE admin/users/#{@property_hash[:id]}"
    self.class.http_delete("admin/users/#{@property_hash[:id]}")    
  end
  
  def update_user
    Puppet.debug "Update User "+resource[:name]
      
    old_object = self.class.user_object(@property_hash[:id])
          
    if old_object[:login] != resource[:login] || old_object[:email] != resource[:email]
      # name is the ID in Puppet - Can't update that...
      params = { 
        :login => resource[:login], 
        :email => resource[:email],
      }
  
      #Puppet.debug "PUT users/#{@property_hash[:id]} PARAMS = "+params.inspect
      response = self.class.http_put("users/#{@property_hash[:id]}", params)  
    end  
    
    if old_object[:is_admin] != resource[:is_admin]
      params = {
        :isGrafanaAdmin => resource[:is_admin],
      }
  
      Puppet.debug "PUT admin/users/#{@property_hash[:id]}/permissions PARAMS = "+params.inspect
      response = self.class.http_put_json("admin/users/#{@property_hash[:id]}/permissions", params)
      Puppet.debug "PUT permissions RESULT: "+response.inspect
    end       
      
    if old_object[:organisations] != resource[:organisations] # rubocop:disable Style/GuardClause
      Puppet.debug "Update organisations for user "+resource[:name]
        
      #Delete or update
      old_object[:organisations].each do |org, role|
        found_role = nil
        resource[:organisations].each do |neworg, newrole|
          found_role = newrole if neworg == org
        end
        
        if found_role.nil?
          org_id = self.class.generic_lookup('orgs', 'name', org, 'id').to_s
          #Puppet.debug "DELETE orgs/#{org_id}/users/#{@property_hash[:id]}"
          response = self.class.http_delete("orgs/#{org_id}/users/#{@property_hash[:id]}") 
        else  
          if found_role != role
            org_id = self.class.generic_lookup('orgs', 'name', org, 'id').to_s
            params = { 
              :orgId  => org_id, 
              :userId => @property_hash[:id], 
              :email  => @property_hash[:email], 
              :login  => @property_hash[:login], 
              :role   => found_role.capitalize,
            }
              
            #Puppet.debug "PATCH orgs/#{org_id}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
            response = self.class.http_patch("orgs/#{org_id}/users/#{@property_hash[:id]}", params) 
          end
        end
      end
       
      # Create
      resource[:organisations].each do |neworg, newrole|
        found = false
        old_object[:organisations].each do |org, _role|
          found = true if neworg == org
        end
        next if found
        
        org_id = self.class.generic_lookup('orgs', 'name', neworg, 'id').to_s
        
        #Puppet.debug "Switch context: ORG = "+org_id
        self.class.http_post("user/using/#{org_id}")
                  
        params = { 
          :loginOrEmail => @property_hash[:login], 
          :role         => newrole.capitalize,
        }
          
        #Puppet.debug "POST orgs/#{org_id}/users/#{@property_hash[:id]} - PARAMS = "+params.inspect
        response = self.class.http_post_json("orgs/#{org_id}/users", params) 
      end
    end
  end  
end