# Custom Type: Grafana - Datasource

Puppet::Type.newtype(:grafana_datasource) do
  @doc = "Grafana Datasource"

  ensurable
  
  newparam(:name, :namevar => true) do
    desc "The datasource name. FORMAT = name_organisation"
  end
  
  newparam(:datasource_name) do
    desc "The datasource real name"
  end
  
  newproperty(:organisation) do
    desc "The organisation that the datasource is linked to"
  end  
  
  newproperty(:type) do
    desc "The datasource type (elasticsearch/graphite/influxdb/opentsdb)"
  end  

  newproperty(:access) do
    desc "The access type (proxy/direct)"
    defaultto :direct
  end  
  
  newproperty(:url) do
    desc "The datasource URL"
  end  
  
  newproperty(:user) do
    desc "The datasource user"
  end  

  newproperty(:password) do
    desc "The datasource password"
  end  
  
  newproperty(:database) do
    desc "The datasource database/index name"
  end  

  newproperty(:basicauth) do
    desc "Whether to enable HTTP Basic Authentication (requires basicAuthUser, basicAuthPassword)"
    defaultto false
  end  
  
  newparam(:basicauth_user) do
    desc "HTTP Basic Authentication Username"
  end  

  newparam(:basicauth_password) do
    desc "HTTP Basic Authentication Password"
  end

  newparam(:json_data) do
    desc "Extra data (usually hash) for configuring new datasources (used by Elasticsearch)"
  end

  newparam(:secure_json_data) do
    desc "Extra [secure] data (usually hash) for configuring new datasources (used by Elasticsearch)"
  end
      
  newproperty(:is_default) do
    desc "Whether the datasource is the default"
    defaultto false
  end  
  
  autorequire(:grafana_organisation) do
    self[:organisation]
  end
  
  # UNUSED:
    # id, orgId, jsonData  
end