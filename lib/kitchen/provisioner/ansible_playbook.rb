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
require 'kitchen/provisioner/ansible/os'
require 'kitchen/provisioner/ansible/librarian'

module Kitchen
  class Busser
    def non_suite_dirs
      %w(data)
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

        @os = Kitchen::Provisioner::Ansible::Os.make(ansible_platform, config)
      end

      def finalize_config!(instance)
        config.instance = instance
        super(instance)
      end

      def verbosity_level(level = 1)
        level = level.to_sym if level.is_a? String
        log_levels = { info: 1, warn: 2, debug: 3, trace: 4 }
        if level.is_a?(Symbol) && log_levels.include?(level)
          # puts "Log Level is: #{log_levels[level]}"
          log_levels[level]
        elsif level.is_a?(Integer) && level > 0
          # puts "Log Level is: #{level}"
          level
        else
          fail 'Invalid ansible_verbosity setting.  Valid values are: 1, 2, 3, 4 OR :info, :warn, :debug, :trace'
        end
      end

      def install_command
        if config[:require_ansible_omnibus]
          cmd = install_omnibus_command
        elsif config[:require_ansible_source]
          info('Installing ansible from source')
          cmd = install_ansible_from_source_command
        elsif config[:require_ansible_repo]
          if !@os.nil?
            info("Installing ansible on #{@os.name}")
            cmd =  @os.install_command
          else
            info('Installing ansible, will try to determine platform os')
            cmd = <<-INSTALL
            if [ ! $(which ansible) ]; then
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
                if ! [ grep -q 'Amazon Linux' /etc/system-release ]; then
                #{Kitchen::Provisioner::Ansible::Os::Redhat.new('redhat', config).install_command}
                else
                #{Kitchen::Provisioner::Ansible::Os::Amazon.new('amazon', config).install_command}
                fi
              elif [ -f /etc/SuSE-release ] || [ -f /etc/SUSE-brand ]; then
                #{Kitchen::Provisioner::Ansible::Os::Suse.new('suse', config).install_command}
              else
                #{Kitchen::Provisioner::Ansible::Os::Debian.new('debian', config).install_command}
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
                if [ $debvers -eq 6 ]; then
                    # in squeeze we need to update alternatives
                    # for enable ruby1.9.1
                    ALTERNATIVES_STRING="--install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 10 --slave /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby1.9.1.1.gz --slave /usr/bin/erb erb /usr/bin/erb1.9.1 --slave /usr/bin/gem gem /usr/bin/gem1.9.1 --slave /usr/bin/irb irb /usr/bin/irb1.9.1 --slave /usr/bin/rake rake /usr/bin/rake1.9.1 --slave /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1 --slave /usr/bin/testrb testrb /usr/bin/testrb1.9.1 --slave /usr/share/man/man1/erb.1.gz erb.1.gz /usr/share/man/man1/erb1.9.1.1.gz --slave /usr/share/man/man1/gem.1.gz gem.1.gz /usr/share/man/man1/gem1.9.1.1.gz --slave /usr/share/man/man1/irb.1.gz irb.1.gz /usr/share/man/man1/irb1.9.1.1.gz --slave /usr/share/man/man1/rake.1.gz rake.1.gz /usr/share/man/man1/rake1.9.1.1.gz --slave /usr/share/man/man1/rdoc.1.gz rdoc.1.gz /usr/share/man/man1/rdoc1.9.1.1.gz --slave /usr/share/man/man1/testrb.1.gz testrb.1.gz /usr/share/man/man1/testrb1.9.1.1.gz"
                    #{sudo_env('update-alternatives')} $ALTERNATIVES_STRING
                    # need to update gem tool because gem 1.3.7 from ruby 1.9.1 is broken
                    #{sudo_env('gem')} install rubygems-update
                    #{sudo_env('/var/lib/gems/1.9.1/bin/update_rubygems')}
                    # clear local gem cache
                    #{sudo_env('rm')} -r /home/vagrant/.gem
                fi
              fi
           fi
           INSTALL

        elsif require_chef_for_busser && chef_url
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
        dirs = %w(modules roles group_vars host_vars)
               .map { |dir| File.join(config[:root_path], dir) }.join(' ')
        cmd = "#{sudo_env('rm')} -rf #{dirs};"
        cmd += " mkdir -p #{config[:root_path]}"
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
        prepare_spec
        prepare_library_plugins
        prepare_callback_plugins
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
          sudo_env('cp'), File.join(config[:root_path], 'ansible.cfg'), '/etc/ansible'
        ].join(' ')

        commands << [
          sudo_env('cp -r'), File.join(config[:root_path], 'group_vars'), '/etc/ansible/.'
        ].join(' ')

        commands << [
          sudo_env('cp -r'), File.join(config[:root_path], 'host_vars'), '/etc/ansible/.'
        ].join(' ')

        if galaxy_requirements
          if config[:require_ansible_source]
            commands << setup_ansible_env_from_source
          end
          commands << [
            'ansible-galaxy', 'install', '--force',
            '-p', File.join(config[:root_path], 'roles'),
            '-r', File.join(config[:root_path], galaxy_requirements)
          ].join(' ')
        end

        command = commands.join(' && ')
        debug(command)
        command
      end

      def run_command
        if !config[:ansible_playbook_command].nil?
          return config[:ansible_playbook_command]
        else

          cmd = ansible_command('ansible-playbook')
          if config[:require_ansible_source]
            # this is an ugly hack to get around the fact that extra vars uses ' and "
            cmd = ansible_command("PATH=#{config[:root_path]}/ansible/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games PYTHONPATH=#{config[:root_path]}/ansible/lib MANPATH=#{config[:root_path]}/ansible/docs/man #{config[:root_path]}/ansible/bin/ansible-playbook")
          end

          if config[:ansible_binary_path]
            cmd = ansible_command("#{config[:ansible_binary_path]}/ansible-playbook")
          end

          cmd = "HTTPS_PROXY=#{https_proxy} #{cmd}" if https_proxy
          cmd = "HTTP_PROXY=#{http_proxy} #{cmd}" if http_proxy
          cmd = "ANSIBLE_ROLES_PATH=#{ansible_roles_path} #{cmd}" if ansible_roles_path

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
            ansible_extra_flags,
            "#{File.join(config[:root_path], File.basename(config[:playbook]))}"
          ].join(' ')
          info("Going to invoke ansible-playbook with: #{result}")
          if config[:idempotency_test]
            result = "#{result} && echo 'Going to invoke ansible-playbook second time:'; #{result} | tee /tmp/idempotency_test.txt; grep -q 'changed=0.*failed=0' /tmp/idempotency_test.txt && (echo 'Idempotence test: PASS' && exit 0) || (echo 'Idempotence test: FAIL' && exit 1)"
            debug("Full cmd with idempotency test: #{result}")
          end

          result
        end
      end

      def ansible_command(script)
        config[:ansible_sudo].nil? || config[:ansible_sudo] == true ? sudo_env(script) : script
      end

      protected

      def load_needed_dependencies!
        return unless File.exist?(ansiblefile)

        debug("Ansiblefile found at #{ansiblefile}, loading Librarian-Ansible")
        Ansible::Librarian.load!(logger)
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
          git clone git://github.com/ansible/ansible.git --recursive #{config[:root_path]}/ansible #{install_source_rev}
          #{sudo_env('easy_install')} pip
          #{sudo_env('pip')} install six paramiko PyYAML Jinja2 httplib2
        fi
        INSTALL
      end

      def install_omnibus_command
        info('Installing ansible using ansible omnibus')

        version = ''
        version = "-v #{config[:ansible_version]}" unless config[:ansible_version].nil?

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

      def tmp_spec_dir
        File.join(sandbox_path, 'spec')
      end

      def tmp_library_plugins_dir
        File.join(sandbox_path, 'library')
      end

      def tmp_callback_plugins_dir
        File.join(sandbox_path, 'callback_plugins')
      end

      def tmp_filter_plugins_dir
        File.join(sandbox_path, 'filter_plugins')
      end

      def tmp_lookup_plugins_dir
        File.join(sandbox_path, 'lookup_plugins')
      end

      def tmp_ansible_vault_password_file_path
        File.join(sandbox_path, File.basename(ansible_vault_password_file).reverse.chomp('.').reverse)
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

      def spec
        'spec'
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

      def library_plugins
        config[:library_plugins_path].to_s
      end

      def callback_plugins
        config[:callback_plugins_path].to_s
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
        config[:ansible_vault_password_file] ? "--vault-password-file=#{File.join(config[:root_path], File.basename(config[:ansible_vault_password_file]).reverse.chomp('.').reverse)}" : nil
      end

      def ansible_inventory_flag
        config[:ansible_inventory_file] ? "--inventory-file=#{File.join(config[:root_path], File.basename(config[:ansible_inventory_file]))}" : "--inventory-file=#{File.join(config[:root_path], 'hosts')}"
      end

      def ansible_extra_flags
        config[:ansible_extra_flags] || ''
      end

      def ansible_platform
        config[:ansible_platform].to_s.downcase
      end

      def update_packages_debian_cmd
        Kitchen::Provisioner::Ansible::Os::Debian.new('debian', config).update_packages_command
      end

      def update_packages_suse_cmd
        Kitchen::Provisioner::Ansible::Os::Suse.new('suse', config).update_packages_command
      end

      def update_packages_redhat_cmd
        Kitchen::Provisioner::Ansible::Os::Redhat.new('redhat', config).update_packages_command
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

        bash_tags = bash_tags.join(',')
        bash_tags = "-t '#{bash_tags}'"
        debug(bash_tags)
        bash_tags
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

      def install_source_rev
        config[:ansible_source_rev] ? "--branch #{config[:ansible_source_rev]}" : nil
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
        cmd = ''
        cmd = " HTTP_PROXY=#{http_proxy}" if http_proxy
        cmd = "#{cmd} HTTPS_PROXY=#{https_proxy}" if https_proxy
        cmd = "#{cmd} NO_PROXY=#{no_proxy}" if no_proxy
        cmd = "export #{cmd}" if cmd != ''
        cmd
      end

      def ansible_roles_path
        roles_paths = []
        roles_paths << File.join(config[:root_path], 'roles') unless config[:roles_path].nil?
        additional_files.each do |additional_file|
          roles_paths << File.join(config[:root_path], File.basename(additional_file))
        end
        if roles_paths.empty?
          info('No roles have been set.')
          nil
        else
          debug("Setting roles_path inside VM to #{ roles_paths.join(':') }")
          roles_paths.join(':')
        end
      end

      def prepare_roles
        info('Preparing roles')
        debug("Using roles from #{roles}")

        resolve_with_librarian if File.exist?(ansiblefile)

        if galaxy_requirements
          FileUtils.cp(galaxy_requirements, File.join(sandbox_path, galaxy_requirements))
        end

        # Detect whether we are running tests on a role
        # If so, make sure to copy into VM so dir structure is like: /tmp/kitchen/roles/role_name

        FileUtils.mkdir_p(File.join(tmp_roles_dir, role_name))
        FileUtils.cp_r(Dir.glob("#{roles}/*"), File.join(tmp_roles_dir, role_name))
      end

      # copy ansible.cfg if found in root of repo
      def prepare_ansible_cfg
        info('Preparing ansible.cfg file')
        ansible_config_file = "#{File.join(sandbox_path, 'ansible.cfg')}"
        if File.exist?('ansible.cfg')
          info('Found existing ansible.cfg')
          FileUtils.cp_r('ansible.cfg', ansible_config_file)
        else
          info('Empty ansible.cfg generated')
          File.open(ansible_config_file, 'wb') do |file|
            file.write("#no config parameters\n")
          end
        end
      end

      def prepare_inventory_file
        info('Preparing inventory file')

        return unless ansible_inventory_file
        debug("Copying inventory file from #{ansible_inventory_file} to #{tmp_inventory_file_path}")
        FileUtils.cp_r(ansible_inventory_file, tmp_inventory_file_path)
      end

      # localhost ansible_connection=local
      # [example_servers]
      # localhost
      def prepare_hosts
        return if ansible_inventory_file
        info('Preparing hosts file')

        if config[:hosts].nil?
          fail 'No hosts have been set. Please specify one in .kitchen.yml'
        else
          debug("Using host from #{hosts}")
          File.open(File.join(sandbox_path, 'hosts'), 'wb') do |file|
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
        if  additional_copy
          additional_files = additional_copy.is_a?(Array) ? additional_copy : [additional_copy]
        end
        additional_files.map(&:to_s)
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

      def prepare_spec
        info('Preparing spec')

        FileUtils.mkdir_p(tmp_spec_dir)

        if spec && File.directory?(spec)
          debug("Using spec from #{spec}")
          FileUtils.cp_r(Dir.glob("#{spec}/*"), tmp_spec_dir, remove_destination: true)
        else
          info 'nothing to do for spec'
        end
      end

      def prepare_library_plugins
        info('Preparing library plugins')
        FileUtils.mkdir_p(tmp_library_plugins_dir)

        if library_plugins && File.directory?(library_plugins)
          debug("Using library plugins from #{library_plugins}")
          FileUtils.cp_r(Dir.glob("#{library_plugins}/{*,!*.pyc}"), tmp_library_plugins_dir, remove_destination: true)
        else
          info 'nothing to do for library plugins'
        end
      end

      def prepare_callback_plugins
        info('Preparing callback plugins')
        FileUtils.mkdir_p(tmp_callback_plugins_dir)

        if callback_plugins && File.directory?(callback_plugins)
          debug("Using callback plugins from #{callback_plugins}")
          FileUtils.cp_r(Dir.glob("#{callback_plugins}/{*,!*.pyc}"), tmp_callback_plugins_dir, remove_destination: true)
        else
          info 'nothing to do for callback plugins'
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
        return unless ansible_vault_password_file

        info('Preparing ansible vault password')
        debug("Copying ansible vault password file from #{ansible_vault_password_file} to #{tmp_ansible_vault_password_file_path}")

        FileUtils.cp(ansible_vault_password_file, tmp_ansible_vault_password_file_path)
      end

      def resolve_with_librarian
        Kitchen.mutex.synchronize do
          Ansible::Librarian.new(ansiblefile, tmp_roles_dir, logger).resolve
        end
      end
    end
  end
end
