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
require 'find'
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
        elsif config[:require_pip]
          info('Installing ansible through pip')
          cmd = install_ansible_from_pip_command
        elsif config[:require_ansible_repo]
          if !@os.nil?
            info("Installing ansible on #{@os.name}")
            cmd =  @os.install_command
          else
            info('Installing ansible, will try to determine platform os')
            cmd = <<-INSTALL

            if [ ! $(which ansible) ]; then
              if [ -f /etc/fedora-release ]; then
                #{Kitchen::Provisioner::Ansible::Os::Fedora.new('fedora', config).install_command}
              elif [ -f /etc/system-release ] && [ `grep -q 'Amazon Linux' /etc/system-release` ]; then
                #{Kitchen::Provisioner::Ansible::Os::Amazon.new('amazon', config).install_command}
              elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
                #{Kitchen::Provisioner::Ansible::Os::Redhat.new('redhat', config).install_command}
              elif [ -f /etc/SuSE-release ] || [ -f /etc/SUSE-brand ]; then
                #{Kitchen::Provisioner::Ansible::Os::Suse.new('suse', config).install_command}
              elif [[ "$OSTYPE" == "darwin"* ]]; then
                #{Kitchen::Provisioner::Ansible::Os::Darwin.new('darwin', config).install_command}
              elif [ -f /etc/alpine-release ] || [ -d /etc/apk ]; then
                #{Kitchen::Provisioner::Ansible::Os::Alpine.new('alpine', config).install_command}
              else
                #{Kitchen::Provisioner::Ansible::Os::Debian.new('debian', config).install_command}
              fi
            fi
            INSTALL
          end
        else
          return
        end

        result = custom_pre_install_command + cmd + install_windows_support + install_busser_prereqs + custom_post_install_command
        debug("Going to install ansible with: #{result}")
        result
      end

      def detect_debug
        if ARGV.include? 'debug'
          result = "1"
        else
          result = "/dev/null"
        end
        return result
      end

      def install_windows_support
        install = ''
        if require_windows_support
            info ("Installing Windows Support")
            info ("Installing pip")
            install << <<-INSTALL
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
                #{sudo_env('yum')} -y install python-devel krb5-devel krb5-libs krb5-workstation gcc > #{detect_debug}
              else
                if [ -f /etc/SuSE-release ]  || [ -f /etc/SUSE-brand ]; then
                  #{sudo_env('zypper')} ar #{python_sles_repo} > #{detect_debug}
                  #{sudo_env('zypper')} --non-interactive install python python-devel krb5-client pam_krb5 > #{detect_debug}
                else
                  #{sudo_env('apt-get')} -y install python-dev libkrb5-dev build-essential > #{detect_debug}
                fi
              fi
            #{export_http_proxy}
            #{sudo_env('easy_install')} pip > #{detect_debug}
            #{sudo_env('pip')} install pywinrm kerberos > #{detect_debug}
            INSTALL
        end
        install
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
            if [ -z `grep -q 'Amazon Linux' /etc/system-release` ]; then
            rhelversion6=$(cat /etc/redhat-release | grep 'release 6')
            rhelversion7=$(cat /etc/redhat-release | grep 'release 7')
            # For CentOS6/CentOS7/RHEL6/RHEL7 install ruby from SCL
            if [ -n "$rhelversion6" ] || [ -n "$rhelversion7" ]; then
            if [ ! -d "/opt/rh/ruby200" ]; then
              echo "-----> Installing ruby200 SCL in CentOS6/CentOS7/RHEL6/RHEL7 to install busser to run tests"
              #{sudo_env('yum')} install -y centos-release-scl > #{detect_debug}
              #{sudo_env('yum')} install -y ruby200 > #{detect_debug}
              #{sudo_env('yum')} install -y ruby200-ruby-devel > #{detect_debug}
              echo "-----> Enabling ruby200"
              source /opt/rh/ruby200/enable
              echo "/opt/rh/ruby200/root/usr/lib64" | sudo tee -a /etc/ld.so.conf
              #{sudo_env('ldconfig')}
              #{sudo_env('ln')} -sf /opt/rh/ruby200/root/usr/bin/ruby /usr/bin/ruby
              #{sudo_env('ln')} -sf /opt/rh/ruby200/root/usr/bin/gem /usr/bin/gem
            fi
            else
              if [ ! $(which ruby) ]; then
                #{update_packages_redhat_cmd} > #{detect_debug}
                #{sudo_env('yum')} -y install ruby ruby-devel > #{detect_debug}
              fi
            fi
            else
                #{update_packages_redhat_cmd} > #{detect_debug}
                #{sudo_env('yum')} -y install ruby ruby-devel gcc > #{detect_debug}
            fi
            elif [ -f /etc/SuSE-release ]  || [ -f /etc/SUSE-brand ]; then
                #{update_packages_suse_cmd} > #{detect_debug}
                #{sudo_env('zypper')} --non-interactive install ruby ruby-devel ca-certificates ca-certificates-cacert ca-certificates-mozilla > #{detect_debug}
                #{sudo_env('gem')} sources --add https://rubygems.org/
            elif [ -f /etc/alpine-release ]  || [ -d /etc/apk ]; then
                #{update_packages_alpine_cmd}
                #{sudo_env('apk')} add ruby ruby-dev ruby-io-console ca-certificates > #{detect_debug}
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
                if [ "$(lsb_release -si)" = "Ubuntu" ]; then
                  ubuntuvers=$(lsb_release -sr | tr -d .)
                  if [ $ubuntuvers -ge 1410 ]; then
                    # Default ruby is 2.x in utopic and newer
                    PACKAGES="ruby ruby-dev"
                  fi
                fi
                #{sudo_env('apt-get')} -y install $PACKAGES > #{detect_debug}
                if [ $debvers -eq 6 ]; then
                    # in squeeze we need to update alternatives
                    # for enable ruby1.9.1
                    ALTERNATIVES_STRING="--install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 10 --slave /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby1.9.1.1.gz --slave /usr/bin/erb erb /usr/bin/erb1.9.1 --slave /usr/bin/gem gem /usr/bin/gem1.9.1 --slave /usr/bin/irb irb /usr/bin/irb1.9.1 --slave /usr/bin/rake rake /usr/bin/rake1.9.1 --slave /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1 --slave /usr/bin/testrb testrb /usr/bin/testrb1.9.1 --slave /usr/share/man/man1/erb.1.gz erb.1.gz /usr/share/man/man1/erb1.9.1.1.gz --slave /usr/share/man/man1/gem.1.gz gem.1.gz /usr/share/man/man1/gem1.9.1.1.gz --slave /usr/share/man/man1/irb.1.gz irb.1.gz /usr/share/man/man1/irb1.9.1.1.gz --slave /usr/share/man/man1/rake.1.gz rake.1.gz /usr/share/man/man1/rake1.9.1.1.gz --slave /usr/share/man/man1/rdoc.1.gz rdoc.1.gz /usr/share/man/man1/rdoc1.9.1.1.gz --slave /usr/share/man/man1/testrb.1.gz testrb.1.gz /usr/share/man/man1/testrb1.9.1.1.gz"
                    #{sudo_env('update-alternatives')} $ALTERNATIVES_STRING
                    # need to update gem tool because gem 1.3.7 from ruby 1.9.1 is broken
                    #{sudo_env('gem')} install rubygems-update > #{detect_debug}
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
              #{sudo_env('sh')} /tmp/install.sh > #{detect_debug}
            fi
            INSTALL
        end

        install
      end

      def custom_pre_install_command
        <<-INSTALL

          #{config[:custom_pre_install_command]}
        INSTALL
      end

      def custom_post_install_command
        <<-INSTALL
          #{config[:custom_post_install_command]}
        INSTALL
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
        prepare_inventory
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
        prepare_kerberos_conf_file
        prepare_additional_ssh_private_keys
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
          sudo_env("#{config[:shell_command]} -c '[ -d /etc/ansible ] || mkdir /etc/ansible'")
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

        if config[:ssh_known_hosts]
          config[:ssh_known_hosts].each do |host|
            info("Add #{host} to ~/.ssh/known_hosts")
            if host.include? ':'
              stripped_host, port = host.split(':')
              commands << "ssh-keyscan -p #{port} #{stripped_host} >> ~/.ssh/known_hosts 2> /dev/null"
            else
              commands << "ssh-keyscan #{host} >> ~/.ssh/known_hosts 2> /dev/null"
            end
          end
        end

        if config[:additional_ssh_private_keys]
          commands << [
            sudo_env('cp -r'), File.join(config[:root_path], 'ssh_private_keys'), '~/.ssh'
          ].join(' ')
        end

        if ansible_inventory
          if File.directory?(ansible_inventory)
            Dir.foreach(ansible_inventory) do |f|
              next if f == "." or f == ".."
              contents = File.open("#{ansible_inventory}/#{f}", 'rb') { |g| g.read }
              if contents.start_with?('#!')
                commands << [
                  sudo_env('chmod +x'), File.join("#{config[:root_path]}/#{File.basename(ansible_inventory)}", File.basename(f))
                ].join(' ')
              end
            end
          else
            contents = File.open(ansible_inventory, 'rb') { |f| f.read }
            if contents.start_with?('#!')
              commands << [
                sudo_env('chmod +x'), File.join(config[:root_path], File.basename(ansible_inventory))
              ].join(' ')
            end
          end
        end

        if galaxy_requirements
          if config[:require_ansible_source]
            commands << setup_ansible_env_from_source
          end
          commands << ansible_galaxy_command
        end

        if kerberos_conf_file
          commands << [
            sudo_env('cp -f'), File.join(config[:root_path], 'krb5.conf'), '/etc'
          ].join(' ')
        end

        command = commands.join(' && ')
        debug("*** COMMAND TO RUN:")
        debug(command)
        command
      end

      def run_command
        return config[:ansible_playbook_command] unless config[:ansible_playbook_command].nil?
        if config[:require_ansible_source] && !config[:ansible_binary_path]
          # this is an ugly hack to get around the fact that extra vars uses ' and "
          cmd = ansible_command("PATH=#{config[:root_path]}/ansible/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games PYTHONPATH=#{config[:root_path]}/ansible/lib MANPATH=#{config[:root_path]}/ansible/docs/man ansible-playbook")
        elsif config[:ansible_binary_path]
          cmd = ansible_command("#{config[:ansible_binary_path]}/ansible-playbook")
        else
          cmd = ansible_command('ansible-playbook')
        end

        cmd = "#{env_vars} #{cmd}" if !config[:env_vars].none?
        cmd = "HTTPS_PROXY=#{https_proxy} #{cmd}" if https_proxy
        cmd = "HTTP_PROXY=#{http_proxy} #{cmd}" if http_proxy
        cmd = "NO_PROXY=#{no_proxy} #{cmd}" if no_proxy
        cmd = "ANSIBLE_ROLES_PATH=#{ansible_roles_path} #{cmd}" if ansible_roles_path
        cmd = "ANSIBLE_HOST_KEY_CHECKING=false #{cmd}" if !ansible_host_key_checking

        cmd = "#{cd_ansible} #{cmd}" if !config[:ansible_sudo].nil? && !config[:ansible_sudo]
        cmd = "#{copy_private_key_cmd} #{cmd}" if config[:private_key]

        result = [
          cmd,
          ansible_inventory_flag,
          ansible_limit_flag,
          ansible_connection_flag,
          "-M #{File.join(config[:root_path], 'modules')}",
          ansible_verbose_flag,
          ansible_check_flag,
          ansible_diff_flag,
          ansible_vault_flag,
          private_key,
          extra_vars,
          extra_vars_file,
          tags,
          ansible_extra_flags,
          "#{File.join(config[:root_path], File.basename(config[:playbook]))}"
        ].join(' ')
        if config[:idempotency_test]
          result = "#{result} && (echo 'Going to invoke ansible-playbook second time:'; #{result} | tee /tmp/idempotency_test.txt; grep -q 'changed=0.*failed=0' /tmp/idempotency_test.txt && (echo 'Idempotence test: PASS' && exit 0) || (echo 'Idempotence test: FAIL' && exit 1))"
        end
        if config[:custom_post_play_command]
          custom_post_play_trap = <<-TRAP
            function custom_post_play_command {
              #{config[:custom_post_play_command]}
            }
            trap custom_post_play_command EXIT
          TRAP
        end
        result = <<-RUN
          #{config[:custom_pre_play_command]}
          #{custom_post_play_trap}
          #{result}
        RUN

        debug("Going to invoke ansible-playbook with: #{result}")
        result

      end

      def ansible_command(script)
        if config[:ansible_sudo].nil? || config[:ansible_sudo] == true
          s = https_proxy ? "https_proxy=#{https_proxy}" : nil
          p = http_proxy ? "http_proxy=#{http_proxy}" : nil
          n = no_proxy ? "no_proxy=#{no_proxy}" : nil
          p || s || n ? " #{p} #{s} #{n} #{config[:sudo_command]} -s #{cd_ansible} #{script}" : "#{config[:sudo_command]} -s #{cd_ansible} #{script}"
        else
          return script
        end
      end

      def ansible_galaxy_command
        cmd = [
            'ansible-galaxy', 'install', '--force',
            '-p', File.join(config[:root_path], 'roles'),
            '-r', File.join(config[:root_path], galaxy_requirements)
        ].join(' ')
        cmd = "https_proxy=#{https_proxy} #{cmd}" if https_proxy
        cmd = "http_proxy=#{http_proxy} #{cmd}" if http_proxy
        cmd = "no_proxy=#{no_proxy} #{cmd}" if no_proxy
        cmd
      end

      def cd_ansible
       # this is not working so just return nil for now
       # File.exist?('ansible.cfg') ? "cd #{config[:root_path]};" : nil
       nil
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
              #{Kitchen::Provisioner::Ansible::Os::Redhat.new('redhat', config).install_epel_repo}
              #{update_packages_redhat_cmd} > #{detect_debug}
              #{sudo_env('yum')} -y install libselinux-python python2-devel git python-setuptools python-setuptools-dev libffi-devel libssl-devel > #{detect_debug}
            else
              if [ -f /etc/SUSE-brand ] || [ -f /etc/SuSE-release ]; then
                #{sudo_env('zypper')} ar #{python_sles_repo} > #{detect_debug}
                #{update_packages_suse_cmd} > #{detect_debug}
                #{sudo_env('zypper')} --non-interactive install python python-devel git python-setuptools python-pip python-six libyaml-devel libffi-devel libopenssl-devel > #{detect_debug}
              else
                #{update_packages_debian_cmd} > #{detect_debug}
                #{sudo_env('apt-get')} -y install git python python-setuptools build-essential python-dev libffi-dev libssl-dev > #{detect_debug}
              fi
            fi

            #{export_http_proxy}
            git clone #{config[:ansible_source_url]} --recursive #{config[:root_path]}/ansible #{install_source_rev}
            #{sudo_env('easy_install')} pip > #{detect_debug}
            #{sudo_env('pip')} install -U setuptools > #{detect_debug}
            #{sudo_env('pip')} install six paramiko PyYAML Jinja2 httplib2 > #{detect_debug}
          fi
          INSTALL
      end

      def install_ansible_from_pip_command
        if config[:ansible_version]=='latest' or config[:ansible_version].nil?
          ansible_version = ''
        else
          ansible_version = "==#{config[:ansible_version]}"
        end
          <<-INSTALL
            if [ ! $(which ansible) ]; then
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
                #{Kitchen::Provisioner::Ansible::Os::Redhat.new('redhat', config).install_epel_repo}
                #{update_packages_redhat_cmd} > #{detect_debug}
                #{sudo_env('yum')} -y install libselinux-python python2-devel git python-setuptools python-setuptools-dev libffi-devel openssl-devel gcc > #{detect_debug}
              else
                if [ -f /etc/SUSE-brand ] || [ -f /etc/SuSE-release ]; then
                  #{sudo_env('zypper')} ar #{python_sles_repo} > #{detect_debug}
                  #{update_packages_suse_cmd} > #{detect_debug}
                  #{sudo_env('zypper')} --non-interactive install python python-devel git python-setuptools python-pip python-six libyaml-devel libffi-devel libopenssl-devel > #{detect_debug}
                else
                  #{update_packages_debian_cmd} > #{detect_debug}
                  #{sudo_env('apt-get')} -y install git python python-setuptools build-essential python-dev libffi-dev libssl-dev > #{detect_debug}
                fi
              fi

            #{export_http_proxy}
            #{sudo_env('easy_install')} pip > #{detect_debug}
            #{sudo_env('pip')} install -U setuptools > #{detect_debug}
            #{sudo_env('pip')} install ansible#{ansible_version} > #{detect_debug}
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
          do_download #{config[:ansible_omnibus_url]} /tmp/ansible_install.sh
          #{sudo_env(config[:shell_command])} /tmp/ansible_install.sh #{version} > #{detect_debug}
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

      def tmp_additional_ssh_private_keys_dir
        File.join(sandbox_path, 'ssh_private_keys')
      end

      def tmp_ansible_vault_password_file_path
        File.join(sandbox_path, File.basename(ansible_vault_password_file).reverse.chomp('.').reverse)
      end

      def tmp_kerberos_conf_file_path
        File.join(sandbox_path, 'krb5.conf')
      end

      def tmp_inventory_path
        File.join(sandbox_path, File.basename(ansible_inventory))
      end

      def ansiblefile
        config[:ansiblefile_path] || ''
      end

      def galaxy_requirements
        config[:requirements_path] || nil
      end

      def env_vars
        return nil if config[:env_vars].none?
        config[:env_vars].map { |k, v| "#{k}=#{v}" }.join(' ')
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
        if config[:role_name]
          config[:role_name]
        elsif File.basename(roles) == 'roles'
          ''
        else
          File.basename(roles)
        end
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

      def ansible_cfg_path
        config[:ansible_cfg_path]
      end

      def recursive_additional_copy
        config[:recursive_additional_copy_path]
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

      def ansible_inventory
        return nil if config[:ansible_inventory] == 'none'
        config[:ansible_inventory] = config[:ansible_inventory_file] if config[:ansible_inventory].nil?
        info('ansible_inventory_file parameter deprecated use ansible_inventory') if config[:ansible_inventory_file]
        config[:ansible_inventory]
      end

      def ansible_debian_version
        if @config[:ansible_version] == 'latest' || @config[:ansible_version] == nil
          ''
        else
          "=#{@config[:ansible_version]}"
        end
      end

      def ansible_connection_flag
        "-c #{config[:ansible_connection]}" if config[:ansible_connection] != 'none'
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
        return nil if config[:ansible_inventory] == 'none'
        ansible_inventory ? "-i #{File.join(config[:root_path], File.basename(ansible_inventory))}" : "-i #{File.join(config[:root_path], 'hosts')}"
      end

      def ansible_limit_flag
        config[:ansible_limit] ? "-l #{config[:ansible_limit]}" : ""
      end

      def ansible_extra_flags
        config[:ansible_extra_flags] || ''
      end

      def ansible_platform
        config[:ansible_platform].to_s.downcase
      end

      def ansible_host_key_checking
        config[:ansible_host_key_checking]
      end

      def private_key
        if config[:private_key]
          "--private-key #{private_key_file}"
        end
      end

      def copy_private_key_cmd
        if !config[:private_key].start_with?('/') && !config[:private_key].start_with?('~')
          ssh_private_key = File.join('~/.ssh', File.basename(config[:private_key]))
          tmp_private_key = File.join(config[:root_path], config[:private_key])
          "rm -rf #{ssh_private_key}; cp #{tmp_private_key} #{ssh_private_key}; chmod 400 #{ssh_private_key};"
        end
      end

      def private_key_file
        if config[:private_key].start_with?('/') || config[:private_key].start_with?('~')
          "#{config[:private_key]}"
        elsif config[:private_key]
          "#{File.join('~/.ssh', File.basename(config[:private_key]))}"
        end
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

      def update_packages_alpine_cmd
        Kitchen::Provisioner::Ansible::Os::Alpine.new('alpine', config).update_packages_command
      end

      def python_sles_repo
        config[:python_sles_repo]
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

      def extra_vars_file
        return nil if config[:extra_vars_file].nil?
        bash_extra_vars = "-e '\@#{config[:extra_vars_file]}'"
        debug(bash_extra_vars)
        bash_extra_vars
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

      def require_windows_support
        config[:require_windows_support]
      end

      def kerberos_conf_file
        config[:kerberos_conf_file]
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

      def sudo_env(pm,home=false)
        s = https_proxy ? "https_proxy=#{https_proxy}" : nil
        p = http_proxy ? "http_proxy=#{http_proxy}" : nil
        n = no_proxy ? "no_proxy=#{no_proxy}" : nil
        if home
          p || s || n ? "#{sudo_home('env')} #{p} #{s} #{n} #{pm}" : "#{sudo_home(pm)}"
        else
          p || s || n ? "#{sudo('env')} #{p} #{s} #{n} #{pm}" : "#{sudo(pm)}"
        end
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
        if config[:additional_copy_role_path]
          if config[:additional_copy_role_path].is_a? String
            roles_paths << File.join(config[:root_path], File.basename(config[:additional_copy_role_path]))
          else
            config[:additional_copy_role_path].each do |path|
              roles_paths << File.join(config[:root_path], File.basename(File.expand_path(path)))
            end
          end
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
        debug("Using roles from #{File.expand_path(roles)}")

        resolve_with_librarian if File.exist?(ansiblefile)

        if galaxy_requirements
          dest = File.join(sandbox_path, galaxy_requirements)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(File.expand_path(galaxy_requirements), dest)
        end

        if config[:additional_copy_role_path]
          if config[:additional_copy_role_path].is_a? String
            debug("Using additional roles copy from #{File.expand_path(config[:additional_copy_role_path])}")
            dest = File.join(sandbox_path, File.basename(File.expand_path(config[:additional_copy_role_path])))
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp_r(File.expand_path(config[:additional_copy_role_path]), dest)
          else
            config[:additional_copy_role_path].each do |path|
              dest = File.join(sandbox_path, File.basename(File.expand_path(path)))
              FileUtils.mkdir_p(File.dirname(dest))
              FileUtils.cp_r(File.expand_path(path), dest)
            end
          end
        end

        FileUtils.mkdir_p(File.join(tmp_roles_dir, role_name))
        Find.find(roles) do |source|
          # Detect whether we are running tests on a role
          # If so, make sure to copy into VM so dir structure is like: /tmp/kitchen/roles/role_name
          role_path = source.sub(/#{roles}|\/roles/, '')
          unless roles =~ /\/roles$/
            role_path = "#{role_name}/#{role_path}"
          end
          target = File.join(tmp_roles_dir, role_path)

          Find.prune if config[:ignore_paths_from_root].include? File.basename(source)
          Find.prune if config[:ignore_extensions_from_root].include? File.extname(source)
          if File.directory?(source)
            FileUtils.mkdir_p(target)
          else
            FileUtils.cp(source, target)
          end
        end
      end

      # copy ansible.cfg if found
      def prepare_ansible_cfg
        info('Preparing ansible.cfg file')
        ansible_config_file = "#{File.join(sandbox_path, 'ansible.cfg')}"
        if !ansible_cfg_path.nil? && File.exist?(ansible_cfg_path)
          info('Found existing ansible.cfg')
          FileUtils.cp_r(ansible_cfg_path, ansible_config_file)
        else
          info('Empty ansible.cfg generated')
          File.open(ansible_config_file, 'wb') do |file|
            file.write("#no config parameters\n")
          end
        end
      end

      def prepare_inventory
        info('Preparing inventory')
        return unless ansible_inventory
        if File.directory?(ansible_inventory)
          debug("Copying inventory directory from #{ansible_inventory} to #{tmp_inventory_path}")
          FileUtils.cp_r(ansible_inventory, sandbox_path)
        else
          debug("Copying inventory file from #{ansible_inventory} to #{tmp_inventory_path}")
          FileUtils.cp_r(ansible_inventory, tmp_inventory_path)
        end
      end

      # localhost ansible_connection=local
      # [example_servers]
      # localhost
      def prepare_hosts
        return if ansible_inventory
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
           info("Copy additional path: #{file}")
           destination = File.join(sandbox_path, File.basename(File.expand_path(file)))
           if File.directory?(File.expand_path(file)) && File.basename(File.expand_path(file))!= ?.
             debug("Copy dir: #{File.expand_path(file)} #{destination}")
             FileUtils.cp_r(File.expand_path(file), destination)
           else
             debug("Copy file: #{file} #{destination}")
             FileUtils.cp(file, destination)
           end
        end
        recursive_additional_files.each do |file|
          info("Copy recursive additional path: #{file}")
          Find.find(file) do |files|
            destination = File.join(sandbox_path, files)
            Find.prune if config[:ignore_paths_from_root].include? File.basename(files)
            Find.prune if "?.".include? File.basename(files)
            Find.prune if config[:ignore_extensions_from_root].include? File.extname(files)
            debug File.basename(files)
            if File.directory?(files)
              FileUtils.mkdir_p(destination)
            else
              FileUtils.cp(files, destination)
            end
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

      def recursive_additional_files
        recursive_additional_files = []
        if  recursive_additional_copy
          recursive_additional_files = recursive_additional_copy.is_a?(Array) ? recursive_additional_copy : [recursive_additional_copy]
        end
        recursive_additional_files.map(&:to_s)
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

      def prepare_additional_ssh_private_keys
        info('Preparing additional_ssh_private_keys')
        FileUtils.mkdir_p(tmp_additional_ssh_private_keys_dir)
        if config[:additional_ssh_private_keys]
          config[:additional_ssh_private_keys].each do |key|
            debug("Adding additional_ssh_private_key file #{key}")
            FileUtils.cp_r(File.expand_path(key), tmp_additional_ssh_private_keys_dir, remove_destination: true)
          end
        else
          info 'nothing to do for additional_ssh_private_keys'
        end
      end

      def prepare_ansible_vault_password_file
        return unless ansible_vault_password_file

        info('Preparing ansible vault password')
        debug("Copying ansible vault password file from #{ansible_vault_password_file} to #{tmp_ansible_vault_password_file_path}")

        FileUtils.cp(File.expand_path(ansible_vault_password_file), tmp_ansible_vault_password_file_path)
      end

      def prepare_kerberos_conf_file
        return unless kerberos_conf_file

        info('Preparing kerberos configuration file')
        debug("Copying kerberos configuration file from #{kerberos_conf_file} to #{tmp_kerberos_conf_file_path}")

        FileUtils.cp(File.expand_path(kerberos_conf_file), tmp_kerberos_conf_file_path)
      end

      def resolve_with_librarian
        Kitchen.mutex.synchronize do
          Ansible::Librarian.new(ansiblefile, tmp_roles_dir, logger).resolve
        end
      end
    end
  end
end
