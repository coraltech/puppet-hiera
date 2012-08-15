
class hiera::default {

  $ensure       = 'present'
  $hierarchy    = [ '%{environment}', '%{hostname}', 'common' ]
  $backends     = [
    {
      'type'    => 'json',
      'datadir' => '/var/lib/hiera',
    },
    {
      'type'       => 'puppet',
      'datasource' => 'data',
    },
  ]

  #---

  case $::operatingsystem {
    debian, ubuntu: {
      $config_name             = 'hiera.yaml'
      $config                  = "/etc/${config_name}"
      $config_template         = 'hiera/hiera.yaml.erb'

      if defined(Class['puppet']) and $puppet::params::config_dir {
        $puppet_config_default = "${puppet::params::config_dir}/${config_name}"
      }
      else {
        $puppet_config_default = "/etc/puppet/${config_name}"
      }

      $puppet_config           = $puppet_config_default
      $puppet_config_template  = 'hiera/hiera.puppet.yaml.erb'

      $build_dir               = '/usr/local/share/hiera'
      $build_gem               = "${build_dir}/hiera-puppet.gem"
    }
    default: {
      fail("The hiera module is not currently supported on ${::operatingsystem}")
    }
  }
}
