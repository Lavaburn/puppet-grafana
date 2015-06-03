require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_dashboard).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Dashboard"
  
  mk_resource_methods

  def flush      
    Puppet.debug "Grafana Dashboard - Flush Started"
      
    if @property_flush[:ensure] == :absent
      deleteDashboard
    elsif @property_flush[:ensure] == :present
      createDashboard
    elsif @property_flush[:ensure] == :latest
      createDashboard(true)
    end 
    
    Puppet.debug "Flush Failed - ENSURE = "+@property_flush[:ensure]
  end  

  def self.instances
    result = Array.new
        
    orgs = get_objects('orgs')
    if orgs != nil
      orgs.each do |org|
        orgId = org["id"].to_s
        Puppet.debug "DS_PREFETCH - ORG = "+orgId
        
        http_post("user/using/"+orgId)
        
        list = get_objects('search')           
        if list != nil      
          list.each do |object|            
            map = getDashboard(orgId, object)
            if map != nil
              Puppet.debug "Dashboard FOUND for ORG #{orgId}: "+map.inspect
              result.push(new(map))
            end  
          end
        end
        
      end
    end
    
    result 
  end

  def self.getDashboard(orgId, object)   
    if object["title"] != nil 
      organisation = genericLookup('orgs', 'id', orgId.to_i, 'name')
      
      dashboard = http_get('dashboards/'+object["uri"])
      version = dashboard["dashboard"]["version"].to_s
      #Puppet.debug "Dashboard "+object["title"]+" is version "+version unless version == '0'
      
      {
        :name           => object["title"]+"_"+organisation,
        :dashboard_name => object["title"],
        :organisation   => organisation,
        
        :version        => version,
        
        #:isStarred      => object["isStarred"],    => user-specific!! (should not manage it at all)
        #:tags           => object["tags"],         => inside dashboard !! (file-based management)
        
        #:id             => object["id"],
        :uri            => object["uri"],
        #:type           => object["type"],
          
        :ensure         => :present
      }
    end
  end
  
  # TYPE SPECIFIC      
  def getFileVersion
    dashboard = loadDashboard
    dashboard['version']
  end
  
  private
  def createDashboard(overwrite = false)
    Puppet.debug "Create/Update Dashboard "+resource[:name]
      
    orgId = self.class.genericLookup('orgs', 'name', resource[:organisation], 'id').to_s      
    Puppet.debug "Switch context: ORG = "+orgId
    self.class.http_post("user/using/"+orgId)
    
    dashboard = loadDashboard
    
    params = {         
      :dashboard => dashboard,
      :overwrite => overwrite,
    }
    
    Puppet.debug "POST dashboards/db PARAMS = "+params.inspect
    response = self.class.http_post_json('dashboards/db', params)
  end

  def deleteDashboard
    Puppet.debug "Delete Dashboard "+resource[:name]
      
    orgId = self.class.genericLookup('orgs', 'name', resource[:organisation], 'id').to_s      
    Puppet.debug "Switch context: ORG = "+orgId
    self.class.http_post("user/using/"+orgId)
    
    Puppet.debug "DELETE dashboards/#{@property_hash[:uri]}"
    response = self.class.http_delete("dashboards/#{@property_hash[:uri]}") 
  end
      
  def loadDashboard
    Puppet.debug "Loading Dashboard from file "+resource[:organisation]+"/"+resource[:dashboard_name]
      
    rest = self.class.get_rest_info
    folder = rest[:dashboards_folder]
    subfolder = folder+'/'+resource[:organisation]
    file = subfolder+'/'+resource[:dashboard_name]+'.json'
    
    data = File.read(file) or raise "Could not read dashboard #{resource[:dashboard_name]}.json from #{subfolder}"
    JSON.load(data)
  end
end