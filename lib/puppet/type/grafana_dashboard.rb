# Custom Type: Grafana - Dashboard

Puppet::Type.newtype(:grafana_dashboard) do
  @doc = "Grafana Dashboard"

#  ensurable do
#    defaultto :present
#    
#    newvalue(:present)    
#    newvalue(:absent)        
#    newvalue(:latest)
#        
#    def insync?(is)
#      @should.each { |should| 
#        case should
#          when :present
#            return true unless [:absent].include?(is)
#          when :absent
#            return true if is == :absent
#          when :latest
#            return false if is == :absent
#            
#            begin
#              @version = provider.getFileVersion
#            rescue => detail
#              raise "Could not retrieve the file version of the dashboard"
#            end
#                        
#            return (@version == provider.version)
#        end
#      }            
#      false   
#    end
#    
#  end
  
  ensurable
  
  newparam(:name, :namevar => true) do
    desc "The dashboard name. FORMAT = name_organisation"
  end

  newparam(:dashboard_name) do
    desc "The dashboard real name"
  end

  newproperty(:organisation) do
    desc "The organisation that the datasource is linked to"
  end 
  
  newproperty(:version) do
    desc "The dashboard version [READ ONLY]"
  end
  
  autorequire(:grafana_organisation) do
    self[:organisation]
  end
  
#  This is managed from file (JSON Dashboard)  
#  newproperty(:isStarred) do
#    desc "Whether the dashboard is starred"
#    defaultto false
#  end  
#
#  newproperty(:tags, :array_matching => :all) do
#    desc "The tags assigned to the dashboard"
#  end  
  
  # UNUSED:
    # id
end