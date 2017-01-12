# Custom Type: Grafana - User

Puppet::Type.newtype(:grafana_user) do
  @doc = "Grafana User"

  ensurable
  
  newparam(:name, :namevar => true) do
    desc "The user full name"
  end
  
  newproperty(:email) do
    desc "The User E-mail Address"
  end  
  
  newproperty(:login) do
    desc "The login for the user"
  end

  newparam(:password) do
    desc "The password for the user login"
  end

  newproperty(:is_admin) do
    desc "Whether the user is an administrator"
    defaultto false
  end
  
  newproperty(:organisations) do
    desc "A Hash with role per organisation. eg. { 'MyOrg' => 'viewer', 'MyOrg2' => 'editor', 'MyOrg3' => 'admin' }"
  end  

  autorequire(:grafana_organisation) do
    self[:organisations].keys
  end
  
  # UNUSED:
    # id
end