require File.join(File.dirname(__FILE__), '..', 'grafana_rest')

Puppet::Type.type(:grafana_dashboard).provide :rest, :parent => Puppet::Provider::Rest do
  desc "REST provider for Grafana Dashboard"
  
  mk_resource_methods

  def flush      
    Puppet.debug "Grafana Dashboard - Flush Started"
      
    if @property_flush[:ensure] == :absent
      delete_dashboard
      return
    end
    
    if @property_flush[:ensure] == :present || @property_flush[:ensure] == :latest
      create_dashboard(false)
      return
    end
        
    Puppet.warning "Flush Failed: ensure = " + @property_flush[:ensure].inspect
  end  

  def self.instances
    result = []
        
    orgs = get_objects('orgs')
    unless orgs.nil?
      orgs.each do |org|
        org_id = org["id"].to_s
        Puppet.debug "DS_PREFETCH - ORG = " + org_id
        
        http_post("user/using/#{org_id}")
        
        list = get_objects('search')          
        next if list.nil? 
        
        list.each do |object|            
          map = dashboard_from_map(org_id, object)
          unless map.nil?
            Puppet.debug "Dashboard FOUND for ORG #{org_id}: "+map.inspect
            result.push(new(map))
          end  
        end
      end
    end
    
    result 
  end

  def self.dashboard_from_map(org_id, object)   
    return if object["title"].nil?
    
    organisation = generic_lookup('orgs', 'id', org_id.to_i, 'name')
    
    dashboard = http_get('dashboards/' + object["uri"])
    version = dashboard["dashboard"]["version"].to_s
    #Puppet.debug "Dashboard "+object["title"]+" is version "+version unless version == '0'
    
    {
      :name           => object["title"] + "_" + organisation,
      :dashboard_name => object["title"],
      :organisation   => organisation,
      :version        => version, 
      :uri            => object["uri"],
      :ensure         => :present
      #:isStarred      => object["isStarred"],    => user-specific!! (should not manage it at all)
      #:tags           => object["tags"],         => inside dashboard !! (file-based management)        
      #:id             => object["id"],
      #:type           => object["type"], 
    }
  end
  
  # TYPE SPECIFIC      
#  def file_version
#    dashboard = load_dashboard
#    dashboard['version']
#  end
  
  private

  def create_dashboard(overwrite)
    Puppet.debug "Create/Update Dashboard " + resource[:name]
      
    org_id = self.class.generic_lookup('orgs', 'name', resource[:organisation], 'id').to_s      
    Puppet.debug "Switch context: ORG = #{org_id}"
    self.class.http_post("user/using/#{org_id}")
    
    dashboard = load_dashboard
    dashboard["id"] = nil
    
    params = {         
      :dashboard => dashboard,
      :overwrite => overwrite,
    }
    
    Puppet.debug "POST dashboards/db PARAMS = " + params.inspect
    self.class.http_post_json('dashboards/db', params)
  end

  def delete_dashboard
    Puppet.debug "Delete Dashboard "+resource[:name]
      
    org_id = self.class.generic_lookup('orgs', 'name', resource[:organisation], 'id').to_s      
    Puppet.debug "Switch context: ORG = " + org_id
    self.class.http_post("user/using/" + org_id)
    
    Puppet.debug "DELETE dashboards/#{@property_hash[:uri]}"
    self.class.http_delete("dashboards/#{@property_hash[:uri]}") 
  end
      
  def load_dashboard
    Puppet.debug "Loading Dashboard from file " + resource[:organisation] + "/" + resource[:dashboard_name]
      
    rest = self.class.rest_info
    folder = rest[:dashboards_folder]
    subfolder = folder + '/' + resource[:organisation]
    file = subfolder + '/' + resource[:dashboard_name]+'.json'
    
    raise "Could not read dashboard #{resource[:dashboard_name]}.json from #{subfolder}" unless (data = File.read(file)) 
    JSON.parse(data)
  end
end