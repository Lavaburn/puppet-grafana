require 'puppet/util/feature'

Puppet.features.add(:api_config) {
   File.exist?("/etc/grafana/api.yaml")
}
