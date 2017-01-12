class Puppet::Provider::Cli < Puppet::Provider
  desc "grafana-cli calls"
    
  def initialize(value={})
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
      if resource = resources[prov.name]
       resource.provider = prov
      end
    end
  end  

  def self.cli(*args) 
    argList = ""
    args.each do |arg|
      argList += " "+arg
    end
        
    result = %x{grafana-cli plugins #{argList}}
    
    if $?.success?
      result
    else
      Puppet.warning("grafana-cli returned non-ok result: #{result}")
      false
    end
  end
end