require File.join(File.dirname(__FILE__), '..', 'grafana_cli')

Puppet::Type.type(:grafana_plugin).provide :cli, :parent => Puppet::Provider::Cli do
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
  
  def self.instances
    installed = cli('ls')

    result = Array.new
    
    installed.split("\n").each do |line|
      if line =~ /(.*) @ (.*)/
        matchdata = line.match(/(.*) @ (.*)/)
        mapData = {
          :ensure  => 'present',
          :name    => matchdata[1].gsub(/\s+/, ""),
          :version => matchdata[2].gsub(/\s+/, "")
        }
        Puppet.debug("mapData = #{mapData}")
    
        object = new(mapData)
        result.push(object)      
      end
    end

    Puppet.debug("result = #{result}")

    result
  end
end
