# Custom Type: Grafana - Organisation

Puppet::Type.newtype(:grafana_organisation) do
  @doc = "Grafana Organisation"

  ensurable
  
  newparam(:name, :namevar => true) do
    desc "The organisation name"
  end
end