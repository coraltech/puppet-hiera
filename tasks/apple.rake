# Title:        Rake task to build Apple packages for Hiera-puppet.
# Author:       Gary Larizza
# Date:         05/18/2012
# Description:  This task will create a DMG-encapsulated package that will
#               install hiera-puppet on OS X systems. This happens by building
#               a directory tree of files that will then be fed to the
#               packagemaker binary (can be installed by installing the
#               XCode Tools) which will create the .pkg file.
#
require 'fileutils'
require 'erb'
require 'find'
require 'pathname'

# Path to Binaries (Constants)
TAR           = '/usr/bin/tar'
CP            = '/bin/cp'
INSTALL       = '/usr/bin/install'
DITTO         = '/usr/bin/ditto'
PACKAGEMAKER  = '/Developer/usr/bin/packagemaker'
SED           = '/usr/bin/sed'

# Setup task to populate all the variables
task :setup do
  @package_name          = "hiera-puppet"
  @version               = `git describe`.chomp
  @title                 = "#{@package_name}-#{@version}"
  @reverse_domain        = "com.puppetlabs.#{@package_name}"
  @package_major_version = @version.split('.')[0]
  @package_minor_version = @version.split('.')[1] +
                           @version.split('.')[2].split('-')[0].split('rc')[0]
  @pm_restart            = 'None'
  @build_date            = Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
end

# method:       make_directory_tree
# description:  This method sets up the directory structure that packagemaker
#               needs to build a package. A prototype.plist file (holding
#               package-specific options) is built from an ERB template located
#               in the tasks/rake/templates directory.
def make_directory_tree
  project_tmp    = "/tmp/#{@package_name}"
  @scratch       = "#{project_tmp}/#{@title}"
  @working_tree  = {
     'scripts'   => "#{@scratch}/scripts",
     'resources' => "#{@scratch}/resources",
     'working'   => "#{@scratch}/root",
     'payload'   => "#{@scratch}/payload",
  }
  puts "Cleaning Tree: #{project_tmp}"
  FileUtils.rm_rf(project_tmp)
  @working_tree.each do |key,val|
    puts "Creating: #{val}"
    FileUtils.mkdir_p(val)
  end
  File.open("#{@scratch}/#{'prototype.plist'}", "w+") do |f|
    f.write(ERB.new(File.read('tasks/templates/prototype.plist.erb')).result())
  end
  File.open("#{@working_tree["scripts"]}/preflight", "w+") do |f|
    f.write(ERB.new(File.read('ext/osx/preflight.erb')).result())
  end
end

# method:        build_dmg
# description:   This method builds a package from the directory structure in
#                /tmp/hiera-puppet and puts it in the
#                /tmp/hiera-puppet/hiera-puppet-#{version}/payload directory. A DMG is
#                created, using hdiutil, based on the contents of the
#                /tmp/hiera-puppet/hiera-puppet-#{version}/payload directory. The resultant
#                DMG is placed in the pkg/apple directory.
#
def build_dmg
  # Local Variables
  dmg_format_code   = 'UDZO'
  zlib_level        = '9'
  dmg_format_option = "-imagekey zlib-level=#{zlib_level}"
  dmg_format        = "#{dmg_format_code} #{dmg_format_option}"
  dmg_file          = "#{@title}.dmg"
  package_file      = "#{@title}.pkg"
  pm_extra_args     = '--verbose --no-recommend --no-relocate'
  package_target_os = '10.5'

  # Build .pkg file
  system("sudo #{PACKAGEMAKER} --root #{@working_tree['working']} \
    --id #{@reverse_domain} \
    --filter DS_Store \
    --target #{package_target_os} \
    --title #{@title} \
    --info #{@scratch}/prototype.plist \
    --scripts #{@working_tree['scripts']} \
    --resources #{@working_tree['resources']} \
    --version #{@version} \
    #{pm_extra_args} --out #{@working_tree['payload']}/#{package_file}")

  # Build .dmg file
  system("sudo hdiutil create -volname #{@title} \
    -srcfolder #{@working_tree['payload']} \
    -uid 99 \
    -gid 99 \
    -ov \
    -format #{dmg_format} \
    #{dmg_file}")

  if File.directory?("#{Pathname.pwd}/pkg/apple")
    FileUtils.mv("#{Pathname.pwd}/#{dmg_file}", "#{Pathname.pwd}/pkg/apple/#{dmg_file}")
    puts "moved:   #{dmg_file} has been moved to #{Pathname.pwd}/pkg/apple/#{dmg_file}"
  else
    FileUtils.mkdir_p("#{Pathname.pwd}/pkg/apple")
    FileUtils.mv(dmg_file, "#{Pathname.pwd}/pkg/apple/#{dmg_file}")
    puts "moved:   #{dmg_file} has been moved to #{Pathname.pwd}/pkg/apple/#{dmg_file}"
  end
end

# method:        pack_source
# description:   This method copies the hiera-puppet source into a directory
#                structure in /tmp/hiera-puppet/hiera-puppet-#{version}/root mirroring the
#                structure on the target system for which the package will be
#                installed. Anything installed into /tmp/hiera-puppet/root will be
#                installed as the package's payload.
#
def pack_source
  work          = "#{@working_tree['working']}"
  source = Pathname.pwd

  # Make all necessary directories
  directories = ["#{work}/usr/bin",
                 "#{work}/usr/share/doc/#{@package_name}",
                 "#{work}/usr/lib/ruby/site_ruby/1.8",
                 "#{work}/usr/lib/ruby/site_ruby/1.8/hiera",
                 "#{work}/usr/lib/ruby/site_ruby/1.8/puppet"]
  FileUtils.mkdir_p(directories)

  # Install necessary files
  system("#{DITTO} #{source}/bin/ #{work}/usr/bin")
  system("#{DITTO} #{source}/lib/ #{work}/usr/lib/ruby/site_ruby/1.8/")

  # Setup a preflight script and replace variables in the files with
  # the correct paths.
  FileUtils.chown('root', 'wheel', "#{@working_tree['scripts']}/preflight")
  FileUtils.chmod(0644, "#{@working_tree['scripts']}/preflight")
  system("#{SED} -i '' \"s\#{SITELIBDIR}\#/usr/lib/ruby/site_ruby/1.8\#g\" #{@working_tree['scripts']}/preflight")
  system("#{SED} -i '' \"s\#{BINDIR}\#/usr/bin\#g\" #{@working_tree['scripts']}/preflight")

  # Install documentation (matching for files with capital letters)
  Dir.foreach("#{source}") do |file|
    system("#{INSTALL} -o root -g wheel -m 644 #{source}/#{file} #{work}/usr/share/doc/#{@package_name}") if file =~ /^[A-Z][A-Z]/
  end

  # Set Permissions
  executable_directories = [ "#{work}/usr/bin", ]
  FileUtils.chmod_R(0755, executable_directories)
  FileUtils.chown_R('root', 'wheel', directories)
  FileUtils.chmod_R(0644, "#{work}/usr/lib/ruby/site_ruby/1.8/")
  FileUtils.chown_R('root', 'wheel', "#{work}/usr/lib/ruby/site_ruby/1.8/")
  Find.find("#{work}/usr/lib/ruby/site_ruby/1.8/") do |dir|
    FileUtils.chmod(0755, dir) if File.directory?(dir)
  end
end

namespace :package do
  desc "Task for building an Apple Package"
  task :apple => [:setup] do
    # Test for Root and Packagemaker binary
    raise "Please run rake as root to build Apple Packages" unless Process.uid == 0
    raise "Packagemaker must be installed. Please install XCode Tools" unless \
      File.exists?('/Developer/usr/bin/packagemaker')

    make_directory_tree
    pack_source
    build_dmg
    FileUtils.chmod_R(0775, "#{Pathname.pwd}/pkg")
  end
end
