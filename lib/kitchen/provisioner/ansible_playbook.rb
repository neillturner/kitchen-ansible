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
require 'kitchen/provisioner/ansible/config'
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

      def initialize(provisioner_config)
        config = Kitchen::Provisioner::Ansible::Config.new(provisioner_config)
        super(config)
      end

      def finalize_config!(instance)
        config.set_instance(instance)
        super(instance)
      end

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

      def install_command
        if config[:require_ansible_omnibus]
          cmd = install_omnibus_command
        elsif config[:require_ansible_source]
          info("Installing ansible from source")
          cmd = install_ansible_from_source_command
        elsif config[:require_ansible_repo]
          case ansible_platform
          when "debian", "ubuntu"
            info("Installing ansible on #{ansible_platform}")
            cmd = install_debian_command
          when "redhat", "centos", "fedora"
            info("Installing ansible on #{ansible_platform}")
            cmd = install_redhat_command
          when "amazon"
            info("Installing ansible on #{ansible_platform}")
            cmd = install_amazon_linux_command
          when "suse", "opensuse", "sles"
            info("Installing ansible on #{ansible_platform}")
            cmd = install_suse_command
          else
            info("Installing ansible, will try to determine platform os")
            cmd = <<-INSTALL
            if [ ! $(which ansible) ]; then
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
                if ! [ grep -q 'Amazon Linux' /etc/system-release ]; then
                  #{install_redhat_command}
                else
                  #{install_amazon_linux_command}
                fi
              elif [ -f /etc/SuSE-release ] || [ -f /etc/SUSE-brand ]; then
                #{install_suse_command}
              else
                #{install_debian_command}
              fi
            fi
            INSTALL
          end
        else
          return
        end
        cmd + install_busser_prereqs
      end

      def install_busser_prereqs
        install = ''
        install << <<-INSTALL
          #{Util.shell_helpers}
          # Fix for https://github.com/test-kitchen/busser/issues/12
          if [ -h /usr/bin/ruby ]; then
              L=$(readlink -f /usr/bin/ruby)
              #{sudo_env('rm')} /usr/bin/ruby
              #{sudo_env('ln')} -s $L /usr/bin/ruby
          fi
          INSTALL

        if require_ruby_for_busser
          install << <<-INSTALL
            if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
            if ! [ grep -q 'Amazon Linux' /etc/system-release ]; then
            rhelversion=$(cat /etc/redhat-release | grep 'release 6')
            # For CentOS6/RHEL6 install ruby from SCL
            if [ -n "$rhelversion" ]; then
            if [ ! -d "/opt/rh/ruby193" ]; then
              echo "-----> Installing ruby SCL in CentOS6/RHEL6 to install busser to run tests"
              #{sudo_env('yum')} install -y centos-release-SCL
              #{sudo_env('yum')} install -y ruby193
              #{sudo_env('yum')} install -y ruby193-ruby-devel
              echo "-----> Enabling ruby193"
              source /opt/rh/ruby193/enable
              echo "/opt/rh/ruby193/root/usr/lib64" | sudo tee -a /etc/ld.so.conf
              #{sudo_env('ldconfig')}
              #{sudo_env('ln')} -s /opt/rh/ruby193/root/usr/bin/ruby /usr/bin/ruby
              #{sudo_env('ln')} -s /opt/rh/ruby193/root/usr/bin/gem /usr/bin/gem
            fi
            else
              if [ ! $(which ruby) ]; then
                #{update_packages_redhat_cmd}
                #{sudo_env('yum')} -y install ruby ruby-devel
              fi
            fi
            else
                #{update_packages_redhat_cmd}
                #{sudo_env('yum')} -y install ruby ruby-devel gcc
            fi
            elif [ -f /etc/SuSE-release ]  || [ -f /etc/SUSE-brand ]; then
                #{update_packages_suse_cmd}
                #{sudo_env('zypper')} --non-interactive install ruby ruby-devel ca-certificates ca-certificates-cacert ca-certificates-mozilla
                #{sudo_env('gem')} sources --add https://rubygems.org/
            else
              if [ ! $(which ruby) ]; then
                #{update_packages_debian_cmd}
                # default package selection for Debian/Ubuntu machines
                PACKAGES="ruby1.9.1 ruby1.9.1-dev"
                if [ "$(lsb_release -si)" = "Debian" ]; then
                  debvers=$(sed 's/\\..*//' /etc/debian_version)
                  if [ $debvers -ge 8 ]; then
                    # this is jessie or better, where ruby1.9.1 is
                    # no longer in the repositories
                    PACKAGES="ruby ruby-dev ruby2.1 ruby2.1-dev"
                  fi
                fi
                #{sudo_env('apt-get')} -y install $PACKAGES
              fi
           fi
           INSTALL

        elsif require_chef_for_busser && chef_url then
          install << <<-INSTALL
            # install chef omnibus so that busser works as this is needed to run tests :(
            if [ ! -d "/opt/chef" ]
            then
              echo "-----> Installing Chef Omnibus to install busser to run tests"
              #{export_http_proxy}
              do_download #{chef_url} /tmp/install.sh
              #{sudo_env('sh')} /tmp/install.sh
            fi
            INSTALL
        end

        install
      end

      def init_command
        dirs = %w{modules roles group_vars host_vars}.
          map { |dir| File.join(config[:root_path], dir) }.join(" ")
        cmd = "#{sudo_env('rm')} -rf #{dirs};"
        cmd = cmd+" mkdir -p #{config[:root_path]}"
        debug(cmd)
        cmd
      end

      def create_sandbox
        super
        debug("Creating local sandbox in #{sandbox_path}")

        yield if block_given?

        prepare_playbook
        prepare_inventory_file
        prepare_modules
        prepare_roles
        prepare_ansible_cfg
        prepare_group_vars
        prepare_additional_copy_path
        prepare_host_vars
        prepare_hosts
        prepare_filter_plugins
        prepare_lookup_plugins
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
            sudo_env("bash -c '[ -d /etc/ansible ] || mkdir /etc/ansible'")
        ]

        commands << [
            sudo_env('cp'),File.join(config[:root_path], 'ansible.cfg'),'/etc/ansible',
        ].join(' ')

        commands << [
            sudo_env('cp -r'), File.join(config[:root_path],'group_vars'), '/etc/ansible/.',
        ].join(' ')

        commands << [
            sudo_env('cp -r'), File.join(config[:root_path],'host_vars'), '/etc/ansible/.',
        ].join(' ')

        if galaxy_requirements
          if config[:require_ansible_source]
            commands << setup_ansible_env_from_source
          end
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
        if config[:require_ansible_source]
          # this is an ugly hack to get around the fact that extra vars uses ' and "
          cmd = ansible_command("PATH=#{config[:root_path]}/ansible/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games PYTHONPATH=#{config[:root_path]}/ansible/lib MANPATH=#{config[:root_path]}/ansible/docs/man #{config[:root_path]}/ansible/bin/ansible-playbook")
        else
          cmd = ansible_command("ansible-playbook")
        end
        if https_proxy
          cmd = "HTTPS_PROXY=#{https_proxy} #{cmd}"
        end
        if http_proxy
          cmd = "HTTP_PROXY=#{http_proxy} #{cmd}"
        end
        result = [
          cmd,
          ansible_inventory_flag,
          "-c #{config[:ansible_connection]}",
          "-M #{File.join(config[:root_path], 'modules')}",
          ansible_verbose_flag,
          ansible_check_flag,
          ansible_diff_flag,
          ansible_vault_flag,
          extra_vars,
          tags,
          "#{File.join(config[:root_path], File.basename(config[:playbook]))}",
        ].join(" ")
        info("Going to invoke ansible-playbook with: #{result}")
        result
      end

      def ansible_command(script)
        config[:ansible_sudo].nil? || config[:ansible_sudo] == true ? sudo_env(script) : script
      end

      protected

      def load_needed_dependencies!
        if File.exists?(ansiblefile)
          debug("Ansiblefile found at #{ansiblefile}, loading Librarian-Ansible")
          Ansible::Librarian.load!(logger)
        end
      end

      def install_ansible_from_source_command
        <<-INSTALL
        if [ ! -d #{config[:root_path]}/ansible ]; then
          if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
            #{install_epel_repo}
            #{update_packages_redhat_cmd}
            #{sudo_env('yum')} -y install libselinux-python python2-devel git python-setuptools python-setuptools-dev
          else
            if [ -f /etc/SUSE-brand ] || [ -f /etc/SuSE-release ]; then
              #{sudo_env('zypper')} ar #{python_sles_repo}
              #{update_packages_suse_cmd}
              #{sudo_env('zypper')} --non-interactive install python python-devel git python-setuptools python-pip python-six libyaml-devel
            else
              #{update_packages_debian_cmd}
              #{sudo_env('apt-get')} -y install git python python-setuptools build-essential python-dev
            fi
          fi

          #{export_http_proxy}
          git clone git://github.com/ansible/ansible.git --recursive #{config[:root_path]}/ansible
          #{sudo_env('easy_install')} pip
          #{sudo_env('pip')} install paramiko PyYAML Jinja2 httplib2
        fi
        INSTALL
      end

      def install_omnibus_command
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
          #{export_http_proxy}
          #{install_epel_repo}
          do_download #{config[:ansible_omnibus_url]} /tmp/ansible_install.sh
          #{sudo_env('sh')} /tmp/ansible_install.sh #{version}
        fi
        INSTALL
      end

      def install_debian_command
        <<-INSTALL
        if [ ! $(which ansible) ]; then
          #{update_packages_debian_cmd}

          ## Install apt-utils to silence debconf warning: http://serverfault.com/q/358943/77156
          #{sudo_env('apt-get')} -y install apt-utils git

          ## Fix debconf tty warning messages
          export DEBIAN_FRONTEND=noninteractive

          ## 13.10, 14.04 include add-apt-repository in software-properties-common
          #{sudo_env('apt-get')} -y install software-properties-common

          ## 10.04, 12.04 include add-apt-repository in
          #{sudo_env('apt-get')} -y install python-software-properties

          ## 10.04 version of add-apt-repository doesn't accept --yes
          ## later versions require interaction from user, so we must specify --yes
          ## First try with -y flag, else if it fails, try without.
          ## "add-apt-repository: error: no such option: -y" is returned but is ok to ignore, we just retry
          #{sudo_env('add-apt-repository')} -y #{ansible_apt_repo} || #{sudo_env('add-apt-repository')} #{ansible_apt_repo}
          #{sudo_env('apt-get')} update
          #{sudo_env('apt-get')} -y install ansible
        fi
        INSTALL
      end

      def install_suse_command
        <<-INSTALL
        if [ ! $(which ansible) ]; then
          #{sudo_env('zypper')} ar #{python_sles_repo}
          #{sudo_env('zypper')} ar #{ansible_sles_repo}
          #{update_packages_suse_cmd}
          #{sudo_env('zypper')} --non-interactive install ansible
        fi
        INSTALL
      end

      def install_redhat_command
        <<-INSTALL
        if [ ! $(which ansible) ]; then
          #{install_epel_repo}
          #{sudo_env('rpm')} -ivh #{ansible_yum_repo}
          #{update_packages_redhat_cmd}
          #{sudo_env('yum')} -y install ansible#{ansible_redhat_version} libselinux-python git
        fi
        INSTALL
      end

      def install_amazon_linux_command
        <<-INSTALL
        if [ ! $(which ansible) ]; then
          #{install_epel_repo}
          #{sudo_env('yum-config-manager')} --enable epel/x86_64
          #{sudo_env('yum')} -y install ansible#{ansible_redhat_version} git
          #{sudo_env('alternatives')} --set python /usr/bin/python2.6
          #{sudo_env('yum')} clean all
          #{sudo_env('yum')} install yum-python26 -y
        fi
        INSTALL
      end

      def setup_ansible_env_from_source
        "cd #{config[:root_path]}/ansible && source hacking/env-setup && cd ../"
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

      def tmp_lookup_plugins_dir
        File.join(sandbox_path, 'lookup_plugins')
      end

      def tmp_ansible_vault_password_file_path
        File.join(sandbox_path, File.basename(ansible_vault_password_file))
      end

      def tmp_inventory_file_path
        File.join(sandbox_path, File.basename(ansible_inventory_file))
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

      def lookup_plugins
        config[:lookup_plugins_path].to_s
      end

      def ansible_vault_password_file
        config[:ansible_vault_password_file]
      end

      def ansible_inventory_file
        config[:ansible_inventory_file]
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

      def ansible_inventory_flag
          config[:ansible_inventory_file] ? "--inventory-file=#{File.join(config[:root_path], File.basename(config[:ansible_inventory_file]))}" : "--inventory-file=#{File.join(config[:root_path], 'hosts')}"
      end

      def ansible_platform
        config[:ansible_platform].to_s.downcase
      end

      def update_packages_debian_cmd
        config[:update_package_repos] ? "#{sudo_env('apt-get')} update" : nil
      end

      def update_packages_suse_cmd
        config[:update_package_repos] ? "#{sudo_env('zypper')} --gpg-auto-import-keys ref" : nil
      end

      def update_packages_redhat_cmd
        config[:update_package_repos] ? "#{sudo_env('yum')} makecache" : nil
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

      def ansible_sles_repo
        config[:ansible_sles_repo]
      end

      def python_sles_repo
        config[:python_sles_repo]
      end

      def chef_url
        config[:chef_bootstrap_url]
      end

      def require_ruby_for_busser
        config[:require_ruby_for_busser]
      end

      def require_chef_for_busser
        config[:require_chef_for_busser]
      end

      def install_epel_repo
        config[:enable_yum_epel] ? sudo_env('yum install epel-release -y') : nil
       end

      def http_proxy
        config[:http_proxy]
      end

      def https_proxy
        config[:https_proxy]
      end

      def no_proxy
        config[:no_proxy]
      end

      def sudo_env(pm)
        s = https_proxy ? "https_proxy=#{https_proxy}" : nil
        p = http_proxy ? "http_proxy=#{http_proxy}" : nil
        n = no_proxy ? "no_proxy=#{no_proxy}" : nil
        p || s ? "#{sudo('env')} #{p} #{s} #{n} #{pm}" : "#{sudo(pm)}"
      end

      def export_http_proxy
        cmd = ""
        cmd = " HTTP_PROXY=#{http_proxy}" if http_proxy
        cmd = "#{cmd} HTTPS_PROXY=#{https_proxy}" if https_proxy
        cmd = "#{cmd} NO_PROXY=#{no_proxy}" if no_proxy
        cmd = "export #{cmd}" if cmd != ""
        cmd
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

      def prepare_inventory_file
        info('Preparing inventory file')

        if ansible_inventory_file
            debug("Copying inventory file from #{ansible_inventory_file} to #{tmp_inventory_file_path}")
            FileUtils.cp_r(ansible_inventory_file, tmp_inventory_file_path)
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
          info('nothing to do for group_vars')
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

      def prepare_lookup_plugins
        info('Preparing lookup_plugins')
        FileUtils.mkdir_p(tmp_lookup_plugins_dir)

        if lookup_plugins && File.directory?(lookup_plugins)
          debug("Using lookup_plugins from #{lookup_plugins}")
          FileUtils.cp_r(Dir.glob("#{lookup_plugins}/*.py"), tmp_lookup_plugins_dir, remove_destination: true)
        else
          info 'nothing to do for lookup_plugins'
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
