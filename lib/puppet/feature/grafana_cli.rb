require 'puppet/util/feature'

Puppet.features.add(:grafana_cli) {
  File.executable?("/usr/sbin/grafana-cli") && File.exist?("/var/lib/grafana/plugins")
}