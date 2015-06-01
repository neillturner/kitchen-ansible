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
      default_config :tags, []
      default_config :ansible_apt_repo, "ppa:ansible/ansible"
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

      default_config :additional_copy_path do |provisioner|
         provisioner.calculate_path('additional_copy', :directory)
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

      default_config :filter_plugins_path do |provisioner|
         provisioner.calculate_path('filter_plugins', :directory)
      end

      default_config :ansible_vault_password_file do |provisioner|
        provisioner.calculate_path('ansible-vault-password', :file)
      end

      default_config :requirements_path, false
      default_config :ansible_verbose, false
      default_config :ansible_verbosity, 1
      default_config :ansible_check, false
      default_config :ansible_diff, false
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
           #{update_packages_debian_cmd}
            ## Install apt-utils to silence debconf warning: http://serverfault.com/q/358943/77156
            #{sudo('apt-get')} -y install apt-utils git
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
           #{update_packages_debian_cmd}
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
          echo "-----> Installing Busser (CentOS)"
            sudo yum install -y centos-release-SCL
            sudo yum install -y ruby193
            echo "-----> Enabling ruby193"
            source /opt/rh/ruby193/enable
            echo "/opt/rh/ruby193/root/usr/lib64" | sudo tee -a /etc/ld.so.conf
            sudo ldconfig
            sudo ln -s /opt/rh/ruby193/root/usr/bin/ruby /usr/bin/ruby
            sudo ln -s /opt/rh/ruby193/root/usr/bin/gem /usr/bin/gem
            echo "-----> Installing gem"
            gem install busser
        INSTALL

        #<<-INSTALL
        #  echo "-----> Installing Busser (Ruby >= 1.9)"
        #    #{sudo('gem')} install busser
        #INSTALL
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
          prepare_additional_copy_path
          prepare_host_vars
          prepare_hosts
          prepare_filter_plugins
          prepare_ansible_vault_password_file
          info('Finished Preparing files for transfer')

        end

        def cleanup_sandbox
          return if sandbox_path.nil?
          debug("Cleaning up local sandbox in #{sandbox_path}")
          FileUtils.rmtree(sandbox_path)
        end

        def prepare_command
          commands = []

          # Prevent failure when ansible package installation doesn't contain /etc/ansible
          commands << [
              sudo("bash -c '[ -d /etc/ansible ] || mkdir /etc/ansible'")
          ]

          commands << [
              sudo('cp'),File.join(config[:root_path], 'ansible.cfg'),'/etc/ansible',
          ].join(' ')

          commands << [
              sudo('cp -r'), File.join(config[:root_path],'group_vars'), '/etc/ansible/.',
          ].join(' ')

          commands << [
              sudo('cp -r'), File.join(config[:root_path],'host_vars'), '/etc/ansible/.',
          ].join(' ')

          if galaxy_requirements
            commands << [
               'ansible-galaxy', 'install', '--force',
               '-p', File.join(config[:root_path], 'roles'),
               '-r', File.join(config[:root_path], galaxy_requirements),
            ].join(' ')
          end

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
            ansible_diff_flag,
            ansible_vault_flag,
            extra_vars,
            tags,
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

        def tmp_filter_plugins_dir
          File.join(sandbox_path, 'filter_plugins')
        end

        def tmp_ansible_vault_password_file_path
          File.join(sandbox_path, File.basename(ansible_vault_password_file))
        end

        def ansiblefile
          config[:ansiblefile_path] || ''
        end

        def galaxy_requirements
          config[:requirements_path] || nil
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

        def additional_copy
          config[:additional_copy_path]
        end

        def host_vars
	  config[:host_vars_path].to_s
        end
        
        def filter_plugins
          config[:filter_plugins_path].to_s
        end

        def ansible_vault_password_file
          config[:ansible_vault_password_file]
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

        def ansible_diff_flag
          config[:ansible_diff] ? '--diff' : nil
        end

        def ansible_vault_flag
          debug(config[:ansible_vault_password_file])
          config[:ansible_vault_password_file] ? "--vault-password-file=#{File.join(config[:root_path], File.basename(config[:ansible_vault_password_file]))}" : nil
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
          bash_vars = config[:extra_vars]
          if config.key?(:attributes) && config[:attributes].key?(:extra_vars) && config[:attributes][:extra_vars].is_a?(Hash)
            bash_vars = config[:attributes][:extra_vars]
          end

          return nil if bash_vars.none?
          bash_vars = JSON.dump(bash_vars)
          bash_vars = "-e '#{bash_vars}'"
          debug(bash_vars)
          bash_vars
        end

        def tags
          bash_tags = config.key?(:attributes) && config[:attributes].key?(:tags) && config[:attributes][:tags].is_a?(Array) ? config[:attributes][:tags] : config[:tags]
          return nil if bash_tags.empty?

          bash_tags = bash_tags.join(",")
          bash_tags = "-t '#{bash_tags}'"
          debug(bash_tags)
          bash_tags
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

          if galaxy_requirements
            FileUtils.cp(galaxy_requirements, File.join(sandbox_path, galaxy_requirements))
          end
                    
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

          roles_paths = []
          roles_paths << File.join(config[:root_path], 'roles') unless config[:roles_path].nil?
          additional_files.each do |additional_file|
            roles_paths << File.join(config[:root_path], File.basename(additional_file))
          end

          if roles_paths.empty?
            info('No roles have been set. empty ansible.cfg generated')
            File.open(ansible_config_file, "wb") do |file|
               file.write("#no roles path specified\n")
            end
          else
            debug("Setting roles_path inside VM to #{ roles_paths.join(':') }")
            File.open( ansible_config_file, "wb") do |file|
               file.write("[defaults]\nroles_path = #{ roles_paths.join(':') }\n")
            end
          end
        end


        # localhost ansible_connection=local
	# [example_servers]
        # localhost
        def prepare_hosts
          info('Preparing hosts file')

          if config[:hosts].nil?
            raise 'No hosts have been set. Please specify one in .kitchen.yml'
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

        def prepare_additional_copy_path
          info('Preparing additional_copy_path')
          additional_files.each do |file|
            destination = File.join(sandbox_path, File.basename(file))
            if File.directory?(file)
              info("Copy dir: #{file} #{destination}")
              FileUtils.cp_r(file, destination)
            else
              info("Copy file: #{file} #{destination}")
              FileUtils.cp file, destination
            end
          end
        end

        def additional_files
          additional_files = []
          if ( additional_copy )
            additional_files = additional_copy.kind_of?(Array) ? additional_copy : [additional_copy]
          end
          additional_files.map { |additional_dir | additional_dir.to_s }
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

        def prepare_filter_plugins
          info('Preparing filter_plugins')
          FileUtils.mkdir_p(tmp_filter_plugins_dir)

          if filter_plugins && File.directory?(filter_plugins)
            debug("Using filter_plugins from #{filter_plugins}")
            FileUtils.cp_r(Dir.glob("#{filter_plugins}/*.py"), tmp_filter_plugins_dir, remove_destination: true)
          else
            info 'nothing to do for filter_plugins'
          end
        end

        def prepare_ansible_vault_password_file
          if ansible_vault_password_file
            info('Preparing ansible vault password')
            debug("Copying ansible vault password file from #{ansible_vault_password_file} to #{tmp_ansible_vault_password_file_path}")

            FileUtils.cp(ansible_vault_password_file, tmp_ansible_vault_password_file_path)
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
