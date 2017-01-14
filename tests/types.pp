#grafana_organisation { 'RCS':
#  ensure => present,
#}

#grafana_user { 'Nicolas2 Truyens2':
#  ensure   => present,
#  email    => 'nicolas@rcswimax.com',  # Should be unique !!
#  login    => 'nicolas',
#  password => 'password',
#  is_admin => false,
#  organisations => {
#    'RCS'   => 'admin',
#    'TEST1' => 'viewer',
#    'TEST2' => 'editor',
#  }
#}

#grafana_datasource { 'graphite_RCS':
#  ensure            => present,
#  datasource_name   => 'graphite',
#  organisation      => 'RCS',
#  type              => 'graphite',
#  access            => 'proxy',
#  url               => 'http://105.235.209.15:8001',
##  user              => '',
##  password          => '',
##  database          => '',
##  basicAuth         => '',
##  basicAuthUser     => '',
##  basicAuthPassword => '',
#  is_default        => true,
#}

#grafana_datasource { 'elasticsearch_RCS':
#  ensure            => present,
#  datasource_name   => 'elasticsearch',
#  organisation      => 'RCS',
#  type              => 'elasticsearch',
#  access            => 'proxy',
#  url               => 'http://172.20.111.69:9200',
##  user              => '',
##  password          => '',
#  database          => 'grafana',
##  basicAuth         => '',
##  basicAuthUser     => '',
##  basicAuthPassword => '',
##  is_default        => true,
#}

# This checks the file version.
# New files will be at version 0 (???)
#grafana_dashboard { 'BIND9 DNS_RCS':
#  ensure         => latest,
#  dashboard_name => "BIND9 DNS",
#  organisation   => 'RCS',
#}

#grafana_dashboard { 'Webservers_RCS':
#  ensure         => present,
#  dashboard_name => "Webservers",
#  organisation   => 'RCS',
#}

#grafana_dashboard { 'Puppet22_RCS':
#  ensure         => absent,
#  dashboard_name => "Puppet22",
#  organisation   => 'RCS',
#}
