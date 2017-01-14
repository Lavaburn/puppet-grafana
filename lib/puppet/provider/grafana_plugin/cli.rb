require File.join(File.dirname(__FILE__), '..', 'grafana_cli')

Puppet::Type.type(:grafana_plugin).provide :cli, :parent => Puppet::Provider::Cli do
  desc "Provider for Grafana Plugin"
  
  mk_resource_methods

  def flush
    if @property_flush[:ensure] == :absent || resource[:ensure] == :absent
      uninstall_plugin
    else
      install_plugin
    end
  end

  def install_plugin
    if resource[:version].nil?
      self.class.cli('install', resource[:name])
    else
      self.class.cli('install', resource[:name], resource[:version])      
    end  
  end
  
  def uninstall_plugin
    self.class.cli('uninstall', resource[:name])
  end
  
  def self.instances
    installed = cli('ls')

    result = []
    
    installed.split("\n").each do |line|
      next unless line =~ /(.*) @ (.*)/
        
      matchdata = line.match(/(.*) @ (.*)/)
      map_data = {
        :ensure  => :present,
        :name    => matchdata[1].gsub(/\s+/, ""),
        :version => matchdata[2].gsub(/\s+/, "")
      }
      Puppet.debug("Plugin: #{map_data}")

      result.push(new(map_data))
    end

    result
  end
end
