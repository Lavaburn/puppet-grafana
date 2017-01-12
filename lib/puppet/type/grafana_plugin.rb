# Custom Type: Grafana - Plugin

Puppet::Type.newtype(:grafana_plugin) do
  @doc = "Grafana Plugin"

  ensurable do
    defaultvalues
    defaultto :present
  end
  
  newparam(:name, :namevar => true) do
    desc "The plugin name."
  end

  newproperty(:version) do
    desc "The plugin version"
  end
  
  autonotify(:service) do
    ['grafana-server']
  end
end