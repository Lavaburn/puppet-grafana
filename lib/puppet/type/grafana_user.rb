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

# ORG-SPECIFIC !!
#  newproperty(:role) do
#    desc "The User Role (admin|viewer)"
#  end  
  
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
  
  # UNUSED:
    # id
end