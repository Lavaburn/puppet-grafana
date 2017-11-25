# Class: grafana::api
#
# This class manages the configuration file that Puppet uses to call the Grafana REST API.
#
# Parameters:
# * password (string): The admin password to authenticate with. [REQUIRED]
# * host (string): The hostname to call the API on. Default: '127.0.0.1'
# * port (integer): The port to call the API on. Default: 3000
# * username (string): The admin username to authenticate with. Default: 'admin'
# * dashboards_folder (path): The folder where dashboards are imported from. Default: '/tmp/grafana-dashboards'
#
# === Authors
#
# Nicolas Truyens <nicolas@truyens.com>
#
class grafana::api (
  String $password,
  String $host              = '127.0.0.1',
  Integer $port              = 3000,
  Boolean $enable_tls       = false,
  Boolean $insecure         = false,
  String $username          = 'admin',
  String $dashboards_folder = '/tmp/grafana-dashboards',
) {
  validate_string($username, $password)
  validate_string($host)
  # TODO - Puppet 4 - validate port
  validate_absolute_path($dashboards_folder)

  # Config file location is currently statically configured (grafana_rest.rb)
  $grafana_config_dir = '/etc/grafana'
  $api_auth_file = "${grafana_config_dir}/api.yaml"

  # How can I reach the REST API?
  $api_host           = '127.0.0.1'   # Always run locally !
  $api_port           = $port
  $admin_user         = $username
  $admin_password     = $password

  file { $api_auth_file:
    ensure  => 'file',
    content => template('grafana/api.yaml.erb')
  }

  # Dependency Gems Installation
  if versioncmp($::puppetversion, '4.0.0') < 0 {
    ensure_packages(['rest-client'], {'ensure' => 'present', 'provider' => 'gem'})
  } else {
    ensure_packages(['rest-client'], {'ensure' => 'present', 'provider' => 'puppet_gem'})
  }
}
