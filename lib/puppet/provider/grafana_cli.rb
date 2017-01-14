class Puppet::Provider::Cli < Puppet::Provider
  desc "grafana-cli calls"
    
  def initialize(value = {})
    super(value)
    @property_flush = {} 
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
      if (resource = resources[prov.name])
       resource.provider = prov
      end
    end
  end  

  def self.cli(*args) 
    arg_list = ""
    args.each do |arg|
      arg_list += " "+arg
    end
        
    result = `grafana-cli plugins #{arg_list}`
    
    if $CHILD_STATUS.success?
      Puppet.debug("grafana-cli returned: #{result}")
      result
    else
      Puppet.warning("grafana-cli returned non-ok result: #{result}")
      false
    end
  end
end