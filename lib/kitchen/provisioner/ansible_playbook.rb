# -*- encoding: utf-8 -*-
#
# Author:: Neill Turner (<neillwturner@gmail.com>)
#
# Copyright (C) 2013,2014 Neill Turner
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# See https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md
# for documentation configuration parameters with ansible_playbook provisioner.
#

require 'json'
require 'kitchen/provisioner/base'
require 'kitchen/provisioner/ansible/librarian'

module Kitchen

  class Busser

    def non_suite_dirs
      %w{data}
    end
  end

  module Provisioner
    #
    # Ansible Playbook provisioner.
    #
    class AnsiblePlaybook < Base
      attr_accessor :tmp_dir

      default_config :require_ansible_omnibus, false
      default_config :ansible_omnibus_url, nil
      default_config :ansible_omnibus_remote_path, '/opt/ansible'
      default_config :ansible_version, nil
      default_config :require_ansible_repo, true
      default_config :extra_vars, {}
      default_config :ansible_apt_repo, "ppa:rquillo/ansible"
      default_config :ansible_yum_repo, "https://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
      default_config :chef_bootstrap_url, "https://www.getchef.com/chef/install.sh"

      default_config :playbook do |provisioner|
        provisioner.calculate_path('default.yml', :file) or
          raise "No playbook found or specified!  Please either set a playbook in your .kitchen.yml config, or create a default wrapper playbook for your role in test/integration/playbooks/default.yml or test/integration/default.yml"
      end

      default_config :roles_path do |provisioner|
         provisioner.calculate_path('roles') or
          raise 'No roles_path detected. Please specify one in .kitchen.yml'
      end

      default_config :group_vars_path do |provisioner|
         provisioner.calculate_path('group_vars', :directory)
      end

      default_config :host_vars_path do |provisioner|
         provisioner.calculate_path('host_vars', :directory)
      end

      default_config :modules_path do |provisioner|
         provisioner.calculate_path('modules', :directory)
      end

      default_config :ansiblefile_path do |provisioner|
        provisioner.calculate_path('Ansiblefile', :file)
      end

      default_config :ansible_verbose, false
      default_config :ansible_verbosity, 1
      default_config :ansible_noop, false   # what is ansible equivalent of dry_run???? ##JMC: I think it's [--check mode](http://docs.ansible.com/playbooks_checkmode.html) TODO: Look into this...
      default_config :ansible_platform, ''
      default_config :update_package_repos, true

      def verbosity_level(level = 1)
        level = level.to_sym if level.is_a? String
        log_levels = { :info => 1, :warn => 2, :debug => 3, :trace => 4 }
        if level.is_a? Symbol and log_levels.include? level
          # puts "Log Level is: #{log_levels[level]}"
          log_levels[level]
        elsif level.is_a? Integer and level > 0
          # puts "Log Level is: #{level}"
          level
        else
          raise 'Invalid ansible_verbosity setting.  Valid values are: 1, 2, 3, 4 OR :info, :warn, :debug, :trace'
        end
      end

      def calculate_path(path, type = :directory)
        base = config[:test_base_path]
        candidates = []
        candidates << File.join(base, instance.suite.name, 'ansible', path)
        candidates << File.join(base, instance.suite.name, path)
        candidates << File.join(base, path)
        candidates << File.join(Dir.pwd, path)
        candidates << File.join(Dir.pwd) if path == 'roles'
    
        debug("Calculating path for #{path}, candidates are: #{candidates.to_s}")
        candidates.find do |c|
          type == :directory ? File.directory?(c) : File.file?(c)
        end
      end

      def install_command
        return unless config[:require_ansible_omnibus] or config[:require_ansible_repo]
        if config[:require_ansible_omnibus]
          info("Installing ansible using ansible omnibus")
          version = if !config[:ansible_version].nil?
            "-v #{config[:ansible_version]}"
          else
            ""
          end
          <<-INSTALL
          #{Util.shell_helpers}

          if [ ! -d "#{config[:ansible_omnibus_remote_path]}" ]; then
            echo "-----> Installing Ansible Omnibus"
            do_download #{config[:ansible_omnibus_url]} /tmp/ansible_install.sh
            #{sudo('sh')} /tmp/ansible_install.sh #{version}
          fi
          #{install_busser}
          INSTALL
        else
          case ansible_platform
          when "debian", "ubuntu"
          info("Installing ansible on #{ansible_platform}")
          <<-INSTALL
          if [ ! $(which ansible) ]; then
            ## Install apt-utils to silence debconf warning: http://serverfault.com/q/358943/77156
            #{sudo('apt-get')} -y install apt-utils
            ## Fix debconf tty warning messages
            export DEBIAN_FRONTEND=noninteractive
            ## 13.10, 14.04 include add-apt-repository in software-properties-common
            #{sudo('apt-get')} -y install software-properties-common
            ## 10.04, 12.04 include add-apt-repository in 
            #{sudo('apt-get')} -y install python-software-properties
          #  #{sudo('wget')} #{ansible_apt_repo}
          #  #{sudo('dpkg')} -i #{ansible_apt_repo_file}
          #  #{sudo('apt-get')} -y autoremove ## These autoremove/autoclean are sometimes useful but
          #  #{sudo('apt-get')} -y autoclean  ## don't seem necessary for the Ubuntu OpsCode bento boxes that are not EOL by Canonical
          #  #{update_packages_debian_cmd}
          #  #{sudo('apt-get')} -y --force-yes install ansible#{ansible_debian_version} python-selinux
            ## 10.04 version of add-apt-repository doesn't accept --yes
            ## later versions require interaction from user, so we must specify --yes
            ## First try with -y flag, else if it fails, try without.
            ## "add-apt-repository: error: no such option: -y" is returned but is ok to ignore, we just retry
            #{sudo('add-apt-repository')} -y #{ansible_apt_repo} || #{sudo('add-apt-repository')} #{ansible_apt_repo}
            #{sudo('apt-get')} update
            #{sudo('apt-get')} -y install ansible
            ## This test works on ubuntu to test if ansible repo has been installed via rquillo ppa repo
            ## if [ $(apt-cache madison ansible | grep -c rquillo ) -gt 0 ]; then echo 'success'; else echo 'fail'; fi
          fi
          #{install_busser}
          INSTALL
          when "redhat", "centos", "fedora"
          info("Installing ansible on #{ansible_platform}")
          <<-INSTALL
          if [ ! $(which ansible) ]; then
            #{sudo('rpm')} -ivh #{ansible_yum_repo}
            #{update_packages_redhat_cmd}
            #{sudo('yum')} -y install ansible#{ansible_redhat_version} libselinux-python
          fi
          #{install_busser}
          INSTALL
         else
          info("Installing ansible, will try to determine platform os")
          <<-INSTALL
          if [ ! $(which ansible) ]; then
            if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
               #{sudo('rpm')} -ivh #{ansible_yum_repo}
               #{update_packages_redhat_cmd}
               #{sudo('yum')} -y install ansible#{ansible_redhat_version} libselinux-python
            else
           ## Install apt-utils to silence debconf warning: http://serverfault.com/q/358943/77156
            #{sudo('apt-get')} -y install apt-utils
            ## Fix debconf tty warning messages
            export DEBIAN_FRONTEND=noninteractive
            ## 13.10, 14.04 include add-apt-repository in software-properties-common
            #{sudo('apt-get')} -y install software-properties-common
            ## 10.04, 12.04 include add-apt-repository in 
            #{sudo('apt-get')} -y install python-software-properties
          #  #{sudo('wget')} #{ansible_apt_repo}
          #  #{sudo('dpkg')} -i #{ansible_apt_repo_file}
          #  #{sudo('apt-get')} -y autoremove ## These autoremove/autoclean are sometimes useful but
          #  #{sudo('apt-get')} -y autoclean  ## don't seem necessary for the Ubuntu OpsCode bento boxes that are not EOL by Canonical
          #  #{update_packages_debian_cmd}
          #  #{sudo('apt-get')} -y --force-yes install ansible#{ansible_debian_version} python-selinux
            ## 10.04 version of add-apt-repository doesn't accept --yes
            ## later versions require interaction from user, so we must specify --yes
            ## First try with -y flag, else if it fails, try without.
            ## "add-apt-repository: error: no such option: -y" is returned but is ok to ignore, we just retry
            #{sudo('add-apt-repository')} -y #{ansible_apt_repo} || #{sudo('add-apt-repository')} #{ansible_apt_repo}
            #{sudo('apt-get')} update
            #{sudo('apt-get')} -y install ansible
            ## This test works on ubuntu to test if ansible repo has been installed via rquillo ppa repo
            ## if [ $(apt-cache madison ansible | grep -c rquillo ) -gt 0 ]; then echo 'success'; else echo 'fail'; fi
            fi
          fi
          #{install_busser}
          INSTALL
         end
        end
      end

      def install_busser
          <<-INSTALL
          #{Util.shell_helpers}
          # install chef omnibus so that busser works as this is needed to run tests :(
          # TODO: work out how to install enough ruby
          # and set busser: { :ruby_bindir => '/usr/bin/ruby' } so that we dont need the
          # whole chef client
          if [ ! -d "/opt/chef" ]
          then
            echo "-----> Installing Chef Omnibus to install busser to run tests"
            do_download #{chef_url} /tmp/install.sh
            #{sudo('sh')} /tmp/install.sh
          fi
          INSTALL
          end

        def init_command
          dirs = %w{modules roles group_vars host_vars}.
            map { |dir| File.join(config[:root_path], dir) }.join(" ")
          cmd = "#{sudo('rm')} -rf #{dirs};"
          cmd = cmd+" mkdir -p #{config[:root_path]}"
          debug(cmd)
          cmd
        end

        def create_sandbox
          super
          debug("Creating local sandbox in #{sandbox_path}")

          yield if block_given?

          prepare_playbook
          prepare_modules
          prepare_roles
          prepare_ansible_cfg
          prepare_group_vars
          prepare_host_vars
          prepare_hosts
          info('Finished Preparing files for transfer')

        end

        def cleanup_sandbox
          return if sandbox_path.nil?
          debug("Cleaning up local sandbox in #{sandbox_path}")
          FileUtils.rmtree(sandbox_path)
        end

        def prepare_command
          commands = []

          commands << [
              sudo('cp'),File.join(config[:root_path], 'ansible.cfg'),'/etc/ansible',
          ].join(' ')

          commands << [
              sudo('cp -r'), File.join(config[:root_path],'group_vars'), '/etc/ansible/.',
          ].join(' ')

          commands << [
              sudo('cp -r'), File.join(config[:root_path],'host_vars'), '/etc/ansible/.',
          ].join(' ')

          command = commands.join(' && ')
          debug(command)
          command
        end

        def run_command
          [
            sudo("ansible-playbook"),
            "-i #{File.join(config[:root_path], 'hosts')}",
            "-M #{File.join(config[:root_path], 'modules')}",
            ansible_verbose_flag,
            ansible_check_flag,
            extra_vars,
            "#{File.join(config[:root_path], File.basename(config[:playbook]))}",
          ].join(" ")
        end

        protected

        def load_needed_dependencies!
          if File.exists?(ansiblefile)
            debug("Ansiblefile found at #{ansiblefile}, loading Librarian-Ansible")
            Ansible::Librarian.load!(logger)
          end
        end

        def tmp_modules_dir
          File.join(sandbox_path, 'modules')
        end

        def tmp_playbook_path
          File.join(sandbox_path, File.basename(playbook))
        end

        def tmp_host_vars_dir
          File.join(sandbox_path, 'host_vars')
        end

        def tmp_roles_dir
          File.join(sandbox_path, 'roles')
        end

        def ansiblefile
          config[:ansiblefile_path] or ''
        end

        def playbook
          config[:playbook]
        end

        def hosts
          config[:hosts]
        end

        def roles
          config[:roles_path]
        end

        def role_name
          File.basename(roles) == 'roles' ? '' : File.basename(roles)
        end

        def modules
          config[:modules_path]
        end

        def group_vars
          config[:group_vars_path].to_s
        end

        def host_vars
	  config[:host_vars_path].to_s
        end

        def ansible_debian_version
          config[:ansible_version] ? "=#{config[:ansible_version]}" : nil
        end

        def ansible_redhat_version
          config[:ansible_version] ? "-#{config[:ansible_version]}" : nil
        end

        def ansible_verbose_flag
          config[:ansible_verbose] ? '-' << ('v' * verbosity_level(config[:ansible_verbosity])) : nil
        end

        def ansible_check_flag
          config[:ansible_check] ? '--check' : nil
        end

        def ansible_platform
          config[:ansible_platform].to_s.downcase
        end

        def update_packages_debian_cmd
          config[:update_package_repos] ? "#{sudo('apt-get')} update" : nil
        end

        def update_packages_redhat_cmd
          config[:update_package_repos] ? "#{sudo('yum')} makecache" : nil
        end

        def extra_vars
          return nil if config[:extra_vars].none?
          bash_vars = JSON.dump(config[:extra_vars])
          bash_vars = "-e '#{bash_vars}'"
          debug(bash_vars)
          bash_vars
        end

        def ansible_apt_repo
          config[:ansible_apt_repo]
        end

        def ansible_apt_repo_file
          config[:ansible_apt_repo].split('/').last
        end

        def ansible_yum_repo
          config[:ansible_yum_repo]
        end

        def chef_url
          config[:chef_bootstrap_url]
        end

        def prepare_roles
          info('Preparing roles')
          debug("Using roles from #{roles}")

          resolve_with_librarian if File.exists?(ansiblefile)
                    
          # Detect whether we are running tests on a role
          # If so, make sure to copy into VM so dir structure is like: /tmp/kitchen/roles/role_name

          FileUtils.mkdir_p(File.join(tmp_roles_dir, role_name))
          FileUtils.cp_r(Dir.glob("#{roles}/*"), File.join(tmp_roles_dir, role_name))
        end

        # /etc/ansible/ansible.cfg should contain
        # roles_path = /tmp/kitchen/roles
        def prepare_ansible_cfg
          info('Preparing ansible.cfg file')
          ansible_config_file = "#{File.join(sandbox_path, 'ansible.cfg')}"
          if config[:roles_path].nil?
            info('No roles has been set. empty ansible.cfg generated')
            File.open(ansible_config_file, "wb") do |file|
               file.write("#no roles path specified\n")
            end
          else
            debug("Setting roles_path inside VM to #{File.join(config[:root_path], 'roles')}")
            File.open( ansible_config_file, "wb") do |file|
               file.write("[defaults]\nroles_path = #{File.join(config[:root_path], 'roles')}\n")
            end
          end
        end


        # localhost ansible_connection=local
	# [example_servers]
        # localhost
        def prepare_hosts
          info('Preparing hosts file')

          if config[:hosts].nil?
            raise 'No hosts has been set. Please specify one in .kitchen.yml'
          else
            debug("Using host from #{hosts}")
            File.open(File.join(sandbox_path, "hosts"), "wb") do |file|
               file.write("localhost ansible_connection=local\n[#{hosts}]\nlocalhost\n")
            end
          end
        end

        def prepare_playbook
          info('Preparing playbook')
          debug("Copying playbook from #{playbook} to #{tmp_playbook_path}")
          FileUtils.cp_r(playbook, tmp_playbook_path)
        end


        def prepare_group_vars
          info('Preparing group_vars')
          tmp_group_vars_dir = File.join(sandbox_path, 'group_vars')
          FileUtils.mkdir_p(tmp_group_vars_dir)

          unless File.directory?(group_vars)
            info 'nothing to do for group_vars'
            return
          end

          debug("Using group_vars from #{group_vars}")
          FileUtils.cp_r(Dir.glob("#{group_vars}/*"), tmp_group_vars_dir)
        end

        def prepare_host_vars
          info('Preparing host_vars')
          FileUtils.mkdir_p(tmp_host_vars_dir)

          unless File.directory?(host_vars)
            info 'nothing to do for host_vars'
            return
          end

          debug("Using host_vars from #{host_vars}")
          FileUtils.cp_r(Dir.glob("#{host_vars}/*"), tmp_host_vars_dir)
        end

        def prepare_modules
          info('Preparing modules')

          FileUtils.mkdir_p(tmp_modules_dir)

          if modules && File.directory?(modules)
            debug("Using modules from #{modules}")
            FileUtils.cp_r(Dir.glob("#{modules}/*"), tmp_modules_dir, remove_destination: true)
          else
            info 'nothing to do for modules'
          end
        end

        def resolve_with_librarian
          Kitchen.mutex.synchronize do
            Ansible::Librarian.new(ansiblefile, tmp_roles_dir, logger).resolve
          end
        end
    end
  end
end
