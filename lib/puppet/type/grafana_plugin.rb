# Custom Type: Grafana - Plugin

Puppet::Type.newtype(:grafana_plugin) do
  @doc = "Grafana Plugin (Supported since v.3.0.0)"

  ensurable do
    #defaultvalues
    defaultto :present
  end
  
  newparam(:name, :namevar => true) do
    desc "The plugin name."
  end

  newproperty(:version) do
    desc "The plugin version. (Only supported from v.4.0.0)"
  end
  
  autonotify(:service) do
    ['grafana-server']
  end
end
