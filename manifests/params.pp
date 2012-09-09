
class hiera::params inherits hiera::default {

  $hiera_ensure            = module_param('ensure')

  #---

  $config_name             = module_param('config_name')
  $config                  = module_param('config')
  $config_template         = module_param('config_template')

  $puppet_config           = module_param('puppet_config')
  $puppet_config_template  = module_param('puppet_config_template')

  #---

  $hierarchy               = module_array('hierarchy')
  $backends                = module_array('backends')
}
