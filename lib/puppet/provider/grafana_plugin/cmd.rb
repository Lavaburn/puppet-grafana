Puppet::Type.type(:grafana_plugin).provide :cmd, :parent => Puppet::Provider do
  desc "Provider for Grafana Plugin"
  
  mk_resource_methods

  def flush
    if @property_flush[:ensure] == :absent
      uninstallPlugin
    else
      installPlugin
    end
  end

  def installPlugin
    if resource[:version].nil?
      self.class.cli('install', resource[:name])
    else
      self.class.cli('install', resource[:name], resource[:version])      
    end  
  end
  
  def uninstallPlugin
    self.class.cli('uninstall', resource[:name])
  end
  
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
  
  def self.instances
    installed = cli('ls')
  
    result = installed.split("\n").collect do |line|
      if line =~ /(.*) @ (.*)/
        matchdata = line.match(/(.*) @ (.*)/)
        new({
          :name    => matchdata[1].gsub(/\s+/, ""),
          :version => matchdata[2].gsub(/\s+/, "")
        })
      end      
    end
    
    result = result.reject do |item| 
      item.nil?
    end
    
    result
  end
end