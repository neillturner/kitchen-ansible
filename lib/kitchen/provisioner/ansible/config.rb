# -*- encoding: utf-8 -*-
#
# Author:: Michael Heap (<m@michaelheap.com>)
#
# Copyright (C) 2015 Michael Heap
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

require 'json'

module Kitchen
  module Provisioner
    module Ansible
      #
      # Ansible Playbook provisioner.
      #
      class Config
        include Kitchen::Configurable

        attr_accessor :instance

        default_config :ansible_sudo, true
        default_config :ansible_verbose, false
        default_config :require_ansible_omnibus, false
        default_config :ansible_omnibus_url, 'https://raw.githubusercontent.com/neillturner/omnibus-ansible/master/ansible_install.sh'
        default_config :ansible_omnibus_remote_path, '/opt/ansible'
        default_config :ansible_version, nil
        default_config :require_ansible_repo, true
        default_config :enable_yum_epel, false
        default_config :extra_vars, {}
        default_config :env_vars, {}
        default_config :tags, []
        default_config :ansible_apt_repo, 'ppa:ansible/ansible'
        default_config :ansible_yum_repo, nil
        default_config :ansible_sles_repo, 'http://download.opensuse.org/repositories/systemsmanagement/SLE_12/systemsmanagement.repo'
        default_config :python_sles_repo, 'http://download.opensuse.org/repositories/devel:/languages:/python/SLE_12/devel:languages:python.repo'
        default_config :chef_bootstrap_url, 'https://www.getchef.com/chef/install.sh'
        # Providing we have Ruby >= 2.0 we only need Ruby. Leaving default to install Chef Omnibus for backwards compatibility.
        # Note: if using kitchen-verifer-serverspec your we can avoid needing Ruby too.
        # (Reference: https://github.com/neillturner/kitchen-ansible/issues/66 )
        default_config :require_chef_for_busser, true
        default_config :require_ruby_for_busser, false
        default_config :require_windows_support, false
        default_config :require_pip, false
        default_config :requirements_path, false
        default_config :ssh_known_hosts, nil
        default_config :ansible_verbose, false
        default_config :ansible_verbosity, 1
        default_config :ansible_check, false
        default_config :ansible_diff, false
        default_config :ansible_platform, ''
        default_config :ansible_connection, 'local'
        default_config :update_package_repos, true
        default_config :require_ansible_source, false
        default_config :ansible_source_rev, nil
        default_config :http_proxy, nil
        default_config :https_proxy, nil
        default_config :no_proxy, nil
        default_config :ansible_playbook_command, nil
        default_config :ansible_host_key_checking, true
        default_config :idempotency_test, nil
        default_config :ansible_inventory, nil
        default_config :ansible_inventory_file, nil
        default_config :ansible_limit, nil
        default_config :ignore_paths_from_root, []
        default_config :role_name, nil
        default_config :additional_copy_role_path, false

        default_config :playbook do |provisioner|
          provisioner.calculate_path('default.yml', :file) ||
            fail('No playbook found or specified!  Please either set a playbook in your .kitchen.yml config, or create a default playbook in test/integration/<suite_name>/ansible/default.yml, test/integration/<suite_name>/default.yml, test/integration/default.yml or in default.yml in the top level')
        end

        default_config :roles_path do |provisioner|
          provisioner.calculate_path('roles') ||
            fail('No roles_path detected. Please specify one in .kitchen.yml')
        end

        default_config :group_vars_path do |provisioner|
          provisioner.calculate_path('group_vars', :directory)
        end

        default_config :additional_copy_path do |provisioner|
          provisioner.calculate_path('additional_copy', :directory)
        end

        default_config :recursive_additional_copy_path do |provisioner|
          provisioner.calculate_path('recursive_additional_copy', :directory)
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

        default_config :library_plugins_path do |provisioner|
          provisioner.calculate_path('library', :directory)
        end

        default_config :callback_plugins_path do |provisioner|
          provisioner.calculate_path('callback_plugins', :directory)
        end

        default_config :filter_plugins_path do |provisioner|
          provisioner.calculate_path('filter_plugins', :directory)
        end

        default_config :lookup_plugins_path do |provisioner|
          provisioner.calculate_path('lookup_plugins', :directory)
        end

        default_config :ansible_vault_password_file do |provisioner|
          provisioner.calculate_path('ansible-vault-password', :file)
        end

        default_config :kerberos_conf_file do |provisioner|
          provisioner.calculate_path('kerberos_conf', :file)
        end

        def initialize(config = {})
          init_config(config)
        end

        def []=(attr, val)
          config[attr] = val
        end

        def [](attr)
          config[attr]
        end

        def key?(k)
          config.key?(k)
        end

        def keys
          config.keys
        end

        def calculate_path(path, type = :directory)
          unless instance
            fail 'Please ensure that an instance is provided before calling calculate_path'
          end

          base = config[:test_base_path]
          candidates = []
          candidates << File.join(base, instance.suite.name, 'ansible', path)
          candidates << File.join(base, instance.suite.name, path)
          candidates << File.join(base, path)
          candidates << File.join(Dir.pwd, path)
          candidates << File.join(Dir.pwd) if path == 'roles'

          candidates.find do |c|
            type == :directory ? File.directory?(c) : File.file?(c)
          end
        end
      end
    end
  end
end
