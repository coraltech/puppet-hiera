
class hiera::default {
  $hiera_ensure = 'present'
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
}
