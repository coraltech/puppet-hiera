
class hiera (

  $ensure                 = $hiera::params::hiera_ensure,
  $config                 = $hiera::params::os_config,
  $puppet_config          = $hiera::params::os_puppet_config,
  $puppet_gem             = $hiera::params::os_temp_gem,
  $hierarchy              = $hiera::params::hierarchy,
  $backends               = $hiera::params::backends,
  $config_template        = $hiera::params::os_config_template,
  $puppet_config_template = $hiera::params::os_puppet_config_template,

) inherits hiera::params {

  #-----------------------------------------------------------------------------
  # Installation

  Exec {
    path => [ '/bin', '/usr/bin', '/usr/local/bin' ],
  }

  package { [ 'hiera', 'hiera-json' ]:
    ensure   => $ensure,
    provider => 'gem',
  }

  file { 'hiera-puppet-gem':
    path      => $puppet_gem,
    ensure    => 'present',
    source    => 'puppet:///modules/puppet/hiera-puppet-1.0.0rc1.31.gem',
    subscribe => [ Package['hiera'], Class['puppet'] ],
  }

  exec { 'hiera-install-puppet-gem':
    command     => "gem install --local '${puppet_gem}'",
    refreshonly => true,
    subscribe   => File['hiera-puppet-gem'],
  }

  exec { 'hiera-remove-puppet-gem':
    command     => "rm -f '${puppet_gem}'",
    refreshonly => true,
    subscribe   => File['hiera-install-puppet-gem'],
  }

  #-----------------------------------------------------------------------------
  # Configuration

  if $config {
    file { 'hiera-config':
      path    => $config,
      content => template($config_template),
      require => Package['hiera'],
    }
  }

  if $puppet_config and defined(Class['puppet']) {
    File {
      path    => $puppet_config,
      content => template($puppet_config_template),
      require => [ Package['hiera'], Class['puppet'] ],
    }

    if defined(Service['puppet']) {
      file { 'hiera-puppet-config':
        notify => Service['puppet'],
      }
    }
    else {
      file { 'hiera-puppet-config': }
    }
  }
}
