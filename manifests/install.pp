# == Class grafana::install
#
class grafana::install {
  case $::grafana::install_method {
    'docker': {
      docker::image { 'grafana/grafana':
        image_tag => 'latest',
        require   => Class['docker']
      }
    }
    'package': {
      case $::osfamily {
        'Debian': {
          package { $::grafana::fontconfig_package:
            ensure => present
          }

          if ($::grafana::package_source == undef) {
            $_package_source = "https://grafanarel.s3.amazonaws.com/builds/grafana_${::grafana::version}_amd64.deb"
          } else {
            $_package_source = $::grafana::package_source
          }

          wget::fetch { 'grafana':
            source      => $_package_source,
            destination => '/tmp/grafana.deb'
          }

          package { $::grafana::package_name:
            ensure   => present,
            provider => 'dpkg',
            source   => '/tmp/grafana.deb',
            require  => [Wget::Fetch['grafana'],Package[$::grafana::fontconfig_package]]
          }
        }
        'RedHat': {
          package { $::grafana::fontconfig_package:
            ensure => present
          }

          if ($::grafana::package_source == undef) {
            $_package_source = "https://grafanarel.s3.amazonaws.com/builds/grafana-${::grafana::version}.x86_64.rpm"
          } else {
            $_package_source = $::grafana::package_source
          }

          package { $::grafana::package_name:
            ensure   => present,
            provider => 'rpm',
            source   => $_package_source,
            require  => Package[$::grafana::fontconfig_package]
          }
        }
        default: {
          fail("${::operatingsystem} not supported")
        }
      }
    }
    'repo': {
      case $::osfamily {
        'Debian': {
          package { $::grafana::fontconfig_package:
            ensure => present
          }

          if ($::grafana::manage_package_repo) {
            $apt_operating_system = downcase($::grafana::apt_os)

            if !defined(Class['apt']) {
              class { 'apt': }
            }

            apt::source { 'grafana':
              location => "https://packagecloud.io/grafana/stable/${apt_operating_system}",
              release  => $::grafana::apt_release,
              repos    => 'main',
              key      =>  {
                'id'     => '418A7F2FB0E1E6E7EABF6FE8C2E73424D59097AB',
                'source' => 'https://packagecloud.io/gpg.key'
              },
              before   => Package[$::grafana::package_name],
            }
            Class['apt::update'] -> Package[$::grafana::package_name]
          }

          package { $::grafana::package_name:
            ensure  => $::grafana::version,
            require => Package[$::grafana::fontconfig_package]
          }
        }
        'RedHat': {
          package { $::grafana::fontconfig_package:
            ensure => present
          }

          if ( $::grafana::manage_package_repo ){
            yumrepo { 'grafana':
              descr    => 'grafana repo',
              baseurl  => 'https://packagecloud.io/grafana/stable/el/6/$basearch',
              gpgcheck => 1,
              gpgkey   => 'https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana',
              enabled  => 1,
              before   => Package[$::grafana::package_name],
            }
          }

          package { $::grafana::package_name:
            ensure  => $::grafana::version,
            require => Package[$::grafana::fontconfig_package]
          }
        }
        default: {
          fail("${::operatingsystem} not supported")
        }
      }
    }
    'archive': {
      # create log directory /var/log/grafana (or parameterize)

      if ($::grafana::archive_source == undef) {
        $_archive_source = "https://grafanarel.s3.amazonaws.com/builds/grafana-${::grafana::version}.linux-x64.tar.gz"
      } else {
        $_archive_source = $::grafana::archive_source
      }

      archive { '/tmp/grafana.tar.gz':
        ensure          => present,
        source          => $_archive_source,
        checksum_verify => false,
        extract         => true,
        extract_path    => $::grafana::install_dir,
        extract_command => 'tar xfz %s --strip-components=1',
        creates         => $::grafana::install_dir,
        cleanup         => true,
      }

      if !defined(User['grafana']){
        user { 'grafana':
          ensure  => present,
          home    => $::grafana::install_dir,
          require => Archive['/tmp/grafana.tar.gz']
        }
      }

      file { $::grafana::install_dir:
        ensure       => directory,
        group        => 'grafana',
        owner        => 'grafana',
        recurse      => true,
        recurselimit => 3,
        require      => User['grafana']
      }
    }
    default: {
      fail("Installation method ${::grafana::install_method} not supported")
    }
  }
}
