require 'beaker-rspec'

# Project root
proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  
RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(:source => proj_root, :module_name => 'grafana')
    
    hosts.each do |host|
      on host, puppet('module', 'install', 'puppetlabs-stdlib'), { :acceptable_exit_codes => [0, 1] }
    end
  end
end
