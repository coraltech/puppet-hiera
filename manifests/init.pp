
class hiera (

  $ensure                 = $hiera::params::hiera_ensure,
  $config                 = $hiera::params::config,
  $puppet_config          = $hiera::params::puppet_config,
  $hierarchy              = $hiera::params::hierarchy,
  $backends               = $hiera::params::backends,
  $config_template        = $hiera::params::config_template,
  $puppet_config_template = $hiera::params::puppet_config_template,

) inherits hiera::params {

  #-----------------------------------------------------------------------------
  # Installation

  package { [ 'hiera', 'hiera-json', 'hiera-puppet' ]:
    ensure   => $ensure,
    provider => 'gem',
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

  if $puppet_config {
    file { 'hiera-puppet-config':
      path    => $puppet_config,
      content => template($puppet_config_template),
      require => [ Package['hiera'], Class['puppet'] ],
    }
  }
}
