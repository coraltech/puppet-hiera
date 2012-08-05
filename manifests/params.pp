
class hiera::params {

  include hiera::default

  #-----------------------------------------------------------------------------
  # General configurations

  if $::hiera_ready {
    $hiera_ensure = hiera('hiera_ensure', $hiera::default::hiera_ensure)
    $hierarchy    = hiera('hiera_hierarchy', $hiera::default::hierarchy)
    $backends     = hiera('hiera_backends', $hiera::default::backends)
  }
  else {
    $hiera_ensure = $hiera::default::hiera_ensure
    $hierarchy    = $hiera::default::hierarchy
    $backends     = $hiera::default::backends
  }

  #-----------------------------------------------------------------------------
  # Operating system specific configurations

  case $::operatingsystem {
    debian, ubuntu: {
      $os_config_name            = 'hiera.yaml'
      $os_config                 = "/etc/${os_config_name}"
      $os_config_template        = 'hiera/hiera.yaml.erb'

      if defined(Class['puppet']) and $puppet::params::os_config_dir {
        $os_puppet_config        = "${puppet::params::os_config_dir}/${os_config_name}"
      }
      else {
        $os_puppet_config        = "/etc/puppet/${os_config_name}"
      }
      $os_puppet_config_template = 'hiera/hiera.puppet.yaml.erb'

      $os_hiera_build_dir        = '/usr/local/share/hiera'
      $os_build_gem              = "${os_hiera_build_dir}/hiera-puppet.gem"
    }
    default: {
      fail("The hiera module is not currently supported on ${::operatingsystem}")
    }
  }
}
