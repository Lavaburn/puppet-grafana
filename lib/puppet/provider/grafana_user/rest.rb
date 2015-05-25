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
    
  def self.getUser(object)   
    if object["login"] != nil 
      {
        :name           => object["name"],  
        :email          => object["email"],    
        :login          => object["login"],   
        :is_admin       => object["isAdmin"],  
          
        :id             => object["id"],     
        
        :ensure         => :present
      }
    end
  end
  
  # TYPE SPECIFIC    
  private
  def createUser
    #Puppet.debug "Create User "+resource[:name]
                
      params = {         
        :name     => resource[:name],
        :email    => resource[:email],
        :login    => resource[:login], 
        :password => resource[:password],
      }
      
      #Puppet.debug "POST org/users PARAMS = "+params.inspect
      response = self.class.http_post('admin/users', params)
  end

  def deleteUser
    #Puppet.debug "Delete User "+resource[:name]
      
    #Puppet.debug "DELETE admin/users/#{@property_hash[:id]}"
    response = self.class.http_delete("admin/users/#{@property_hash[:id]}")    
  end
  
  def updateUser
    #Puppet.debug "Update User "+resource[:name]
          
    if @property_hash[:login] != resource[:login] or @property_hash[:email] != resource[:email]
      params = {    # name is the ID in Puppet - Can't update that...
        :login          => resource[:login], 
        :email          => resource[:email],
      }
  
      #Puppet.debug "PUT users/#{@property_hash[:id]} PARAMS = "+params.inspect
      response = self.class.http_put("users/#{@property_hash[:id]}", params)  
    end  
    
    if @property_hash[:is_admin] != resource[:is_admin]
      params = {
        :isGrafanaAdmin => resource[:is_admin],        
      }
  
      #Puppet.debug "PUT users/#{@property_hash[:id]}/permissions PARAMS = "+params.inspect
      response = self.class.http_put("admin/users/#{@property_hash[:id]}/permissions", params)    
    end       
  end  
end