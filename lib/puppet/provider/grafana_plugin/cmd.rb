require File.join(File.dirname(__FILE__), '..', 'grafana_plugin')

Puppet::Type.type(:grafana_plugin).provide :cmd, :parent => Puppet::Provider do
  desc "Provider for Grafana Plugin"
  
  mk_resource_methods

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

  def flush
    if @property_flush[:ensure] == :absent
      uninstallPlugin
    else
      installPlugin
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
  
  def installPlugin
    if resource[:version].nil?
      cli('install', resource[:name])
    else
      cli('install', resource[:name], resource[:version])      
    end  
  end
  
  def uninstallPlugin
    cli('uninstall', resource[:name])
  end
end